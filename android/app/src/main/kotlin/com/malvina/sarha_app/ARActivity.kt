package com.malvina.sarha_app

import android.Manifest
import android.content.pm.PackageManager
import android.opengl.GLSurfaceView
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Session
import com.google.ar.core.exceptions.*
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class ARActivity : AppCompatActivity() {
    private lateinit var surfaceView: GLSurfaceView
    private var session: Session? = null
    private val CAMERA_PERMISSION_CODE = 100

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_ar)

        surfaceView = findViewById(R.id.surfaceView)

        // Check camera permission
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CAMERA),
                CAMERA_PERMISSION_CODE
            )
        } else {
            setupARSession()
        }
    }

    private fun setupARSession() {
        try {
            when (ArCoreApk.getInstance().requestInstall(this, true)) {
                ArCoreApk.InstallStatus.INSTALL_REQUESTED -> {
                    Toast.makeText(this, "Installing ARCore...", Toast.LENGTH_SHORT).show()
                    return
                }
                ArCoreApk.InstallStatus.INSTALLED -> {
                    // Continue
                }
            }

            // Create ARCore session
            session = Session(this).apply {
                val config = Config(this)
                config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                configure(config)
            }

            // Setup OpenGL surface
            surfaceView.preserveEGLContextOnPause = true
            surfaceView.setEGLContextClientVersion(2)
            surfaceView.setEGLConfigChooser(8, 8, 8, 8, 16, 0)
            surfaceView.setRenderer(object : GLSurfaceView.Renderer {
                override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
                    // Clear to black
                    gl?.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
                }

                override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
                    gl?.glViewport(0, 0, width, height)
                    session?.setDisplayGeometry(0, width, height)
                }

                override fun onDrawFrame(gl: GL10?) {
                    gl?.glClear(GL10.GL_COLOR_BUFFER_BIT or GL10.GL_DEPTH_BUFFER_BIT)
                    
                    session?.let { session ->
                        try {
                            session.setCameraTextureName(0)
                            val frame = session.update()
                            
                            // Camera background is rendered here
                            // For now, just showing camera feed
                            
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }
            })
            surfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY

            Toast.makeText(this, "AR Camera Active! Point at surfaces.", Toast.LENGTH_LONG).show()

        } catch (e: UnavailableArcoreNotInstalledException) {
            Toast.makeText(this, "Please install ARCore", Toast.LENGTH_LONG).show()
            finish()
        } catch (e: UnavailableApkTooOldException) {
            Toast.makeText(this, "Please update ARCore", Toast.LENGTH_LONG).show()
            finish()
        } catch (e: UnavailableSdkTooOldException) {
            Toast.makeText(this, "Please update this app", Toast.LENGTH_LONG).show()
            finish()
        } catch (e: UnavailableDeviceNotCompatibleException) {
            Toast.makeText(this, "This device does not support AR", Toast.LENGTH_LONG).show()
            finish()
        } catch (e: Exception) {
            Toast.makeText(this, "Failed to create AR session", Toast.LENGTH_LONG).show()
            finish()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CAMERA_PERMISSION_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                setupARSession()
            } else {
                Toast.makeText(this, "Camera permission is required for AR", Toast.LENGTH_SHORT).show()
                finish()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        try {
            session?.resume()
            surfaceView.onResume()
        } catch (e: Exception) {
            Toast.makeText(this, "Camera not available", Toast.LENGTH_SHORT).show()
            finish()
        }
    }

    override fun onPause() {
        super.onPause()
        surfaceView.onPause()
        session?.pause()
    }

    override fun onDestroy() {
        super.onDestroy()
        session?.close()
        session = null
    }
}