const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const geofireCommon = require("geofire-common");

initializeApp();

exports.sendNotificationToNearbyResponders = onDocumentCreated(
    "reports/{reportId}",
    async (event) => {
        try {
            const reportData = event.data.data();
            const reportId = event.params.reportId;

            console.log("🚨 New hazard reported:", reportId);
            console.log("📍 Hazard data:", reportData);

            if (!reportData.location ||
                !reportData.location.latitude ||
                !reportData.location.longitude) {
                console.error("❌ No valid location in report");
                return null;
            }

            const hazardLat = reportData.location.latitude;
            const hazardLng = reportData.location.longitude;
            const hazardType = reportData.hazardType || "Road Hazard";

            console.log(`📍 Hazard: ${hazardLat}, ${hazardLng}`);

            const RADIUS_KM = 5;
            const RADIUS_M = RADIUS_KM * 1000;

            const db = getFirestore();
            const usersSnapshot = await db.collection("users").get();

            if (usersSnapshot.empty) {
                console.log("👥 No users found");
                return null;
            }

            console.log(`👥 Total users: ${usersSnapshot.size}`);

            const notifications = [];
            let nearbyCount = 0;

            for (const userDoc of usersSnapshot.docs) {
                const userData = userDoc.data();

                if (!userData.fcmToken) {
                    console.log(`⚠️ User ${userDoc.id} no token`);
                    continue;
                }

                if (!userData.location ||
                    !userData.location.latitude ||
                    !userData.location.longitude) {
                    console.log(`⚠️ User ${userDoc.id} no location`);
                    continue;
                }

                const userLat = userData.location.latitude;
                const userLng = userData.location.longitude;

                const distanceInM = geofireCommon.distanceBetween(
                    [hazardLat, hazardLng],
                    [userLat, userLng],
                ) * 1000;

                const distStr = distanceInM.toFixed(0);
                console.log(`📏 User ${userDoc.id} is ${distStr}m away`);

                if (distanceInM <= RADIUS_M) {
                    nearbyCount++;
                    const distKm = (distanceInM / 1000).toFixed(1);

                    notifications.push({
                        token: userData.fcmToken,
                        notification: {
                            title: "🚨 New Road Hazard Alert",
                            body: `${hazardType} reported ${distKm}km away`,
                        },
                        data: {
                            reportId: reportId,
                            hazardType: hazardType,
                            latitude: hazardLat.toString(),
                            longitude: hazardLng.toString(),
                            distance: distanceInM.toFixed(0),
                        },
                        android: {
                            priority: "high",
                            notification: {
                                sound: "default",
                                channelId: "hazard_alerts",
                            },
                        },
                    });

                    console.log(`✅ Queued for ${userDoc.id}`);
                }
            }

            console.log(`📤 Sending ${notifications.length} notifications`);

            if (notifications.length > 0) {
                const messaging = getMessaging();
                const response = await messaging.sendEach(notifications);

                console.log(`✅ Sent ${response.successCount}`);
                console.log(`❌ Failed ${response.failureCount}`);

                return {
                    success: true,
                    totalSent: response.successCount,
                    totalFailed: response.failureCount,
                    nearbyUsers: nearbyCount,
                };
            } else {
                console.log("⚠️ No nearby users within 5km");
                return {success: true, message: "No nearby users"};
            }
        } catch (error) {
            console.error("❌ Error:", error);
            return {success: false, error: error.message};
        }
    },
);