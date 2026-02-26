const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const geofireCommon = require("geofire-common");

initializeApp();

exports.sendNotificationToNearbyResponders = onDocumentCreated(
    "hazards/{hazardId}",  // ✅ FIXED: was "reports/{reportId}"
    async (event) => {
        try {
            const hazardData = event.data.data();
            const hazardId = event.params.hazardId;

            console.log("🚨 New hazard detected:", hazardId);
            console.log("📍 Hazard data:", hazardData);

            // ✅ FIXED: fields are top-level, not nested under location
            if (!hazardData.latitude || !hazardData.longitude) {
                console.error("❌ No valid location in hazard");
                return null;
            }

            const hazardLat = hazardData.latitude;
            const hazardLng = hazardData.longitude;
            const hazardType = hazardData.type || "Road Hazard";
            const description = hazardData.description || "Hazard detected nearby";

            console.log(`📍 Hazard location: ${hazardLat}, ${hazardLng}`);
            console.log(`🚨 Type: ${hazardType}`);

            const RADIUS_KM = 5;
            const RADIUS_M = RADIUS_KM * 1000;

            const db = getFirestore();

            // Notify responders
            const respondersSnapshot = await db.collection("responders").get();
            // Also notify nearby users
            const usersSnapshot = await db.collection("users").get();

            const allDocs = [...respondersSnapshot.docs, ...usersSnapshot.docs];

            if (allDocs.length === 0) {
                console.log("👥 No users or responders found");
                return null;
            }

            console.log(`👥 Total people to check: ${allDocs.length}`);

            const notifications = [];
            let nearbyCount = 0;

            for (const doc of allDocs) {
                const userData = doc.data();

                if (!userData.fcmToken) {
                    console.log(`⚠️ ${doc.id} has no FCM token`);
                    continue;
                }

                // Responders get notified regardless of location
                const isResponder = respondersSnapshot.docs.some(r => r.id === doc.id);

                let shouldNotify = isResponder; // Always notify responders

                // For regular users, check distance
                if (!isResponder && userData.latitude && userData.longitude) {
                    const distanceInM = geofireCommon.distanceBetween(
                        [hazardLat, hazardLng],
                        [userData.latitude, userData.longitude],
                    ) * 1000;

                    console.log(`📏 User ${doc.id} is ${distanceInM.toFixed(0)}m away`);
                    shouldNotify = distanceInM <= RADIUS_M;
                }

                if (shouldNotify) {
                    nearbyCount++;

                    notifications.push({
                        token: userData.fcmToken,
                        notification: {
                            title: `🚨 ${hazardType} Detected`,
                            body: description,
                        },
                        data: {
                            hazardId: hazardId,
                            hazardType: hazardType,
                            latitude: hazardLat.toString(),
                            longitude: hazardLng.toString(),
                            type: "hazard_alert",
                        },
                        android: {
                            priority: "high",
                            notification: {
                                sound: "default",
                                channelId: "hazard_alerts",
                            },
                        },
                        apns: {
                            payload: {
                                aps: {
                                    sound: "default",
                                    badge: 1,
                                },
                            },
                        },
                    });

                    console.log(`✅ Queued notification for ${doc.id}`);
                }
            }

            console.log(`📤 Sending ${notifications.length} notifications...`);

            if (notifications.length > 0) {
                const messaging = getMessaging();
                const response = await messaging.sendEach(notifications);

                console.log(`✅ Successfully sent: ${response.successCount}`);
                console.log(`❌ Failed: ${response.failureCount}`);

                // Log any failures
                response.responses.forEach((resp, idx) => {
                    if (!resp.success) {
                        console.error(`❌ Failed for token ${idx}:`, resp.error);
                    }
                });

                return {
                    success: true,
                    totalSent: response.successCount,
                    totalFailed: response.failureCount,
                    nearbyPeople: nearbyCount,
                };
            } else {
                console.log("⚠️ No nearby users or responders to notify");
                return {success: true, message: "No nearby users"};
            }
        } catch (error) {
            console.error("❌ Cloud Function error:", error);
            return {success: false, error: error.message};
        }
    },
);