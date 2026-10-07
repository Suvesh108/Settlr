import os
import shutil
import re

def patch_android_project():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    android_dir = os.path.join(base_dir, 'android')
    assets_dir = os.path.join(base_dir, 'android_assets')
    res_dir = os.path.join(android_dir, 'app', 'src', 'main', 'res')
    manifest_path = os.path.join(android_dir, 'app', 'src', 'main', 'AndroidManifest.xml')

    print(f"Patching Android project in {android_dir}...")

    # 1. Copy mipmaps and xml
    src_res = os.path.join(assets_dir, 'res')
    if os.path.exists(src_res):
        for item in os.listdir(src_res):
            s = os.path.join(src_res, item)
            d = os.path.join(res_dir, item)
            if os.path.isdir(s):
                os.makedirs(d, exist_ok=True)
                for f in os.listdir(s):
                    shutil.copy2(os.path.join(s, f), os.path.join(d, f))
                    print(f"Copied {f} to {d}")

    # 2. Copy MainActivity.kt
    kt_src = os.path.join(assets_dir, 'MainActivity.kt')
    # Find all MainActivity.kt locations under android/app/src/main/kotlin/
    kotlin_dir = os.path.join(android_dir, 'app', 'src', 'main', 'kotlin')
    if os.path.exists(kotlin_dir):
        copied = False
        for root, dirs, files in os.walk(kotlin_dir):
            if 'MainActivity.kt' in files:
                dest_file = os.path.join(root, 'MainActivity.kt')
                # Read package from destination to ensure package statement matches
                with open(dest_file, 'r', encoding='utf-8') as f:
                    orig_content = f.read()
                pkg_match = re.search(r'package\s+([\w\.]+)', orig_content)
                pkg_name = pkg_match.group(1) if pkg_match else "com.settlr.settlr_mobile"
                
                with open(kt_src, 'r', encoding='utf-8') as f:
                    new_content = f.read()
                new_content = re.sub(r'package\s+[\w\.]+', f'package {pkg_name}', new_content)
                
                with open(dest_file, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"Replaced MainActivity.kt at {dest_file} with package {pkg_name}")
                copied = True
        if not copied:
            target_pkg_dir = os.path.join(kotlin_dir, 'com', 'settlr', 'settlr_mobile')
            os.makedirs(target_pkg_dir, exist_ok=True)
            shutil.copy2(kt_src, os.path.join(target_pkg_dir, 'MainActivity.kt'))
            print("Placed MainActivity.kt in default package dir")

    # 3. Patch AndroidManifest.xml
    if os.path.exists(manifest_path):
        with open(manifest_path, 'r', encoding='utf-8') as f:
            manifest = f.read()

        permissions = """
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
"""
        if '<uses-permission android:name="android.permission.INTERNET"' not in manifest:
            manifest = re.sub(r'(<manifest[^>]*>)', r'\1' + permissions, manifest, count=1)

        # Add usesCleartextTraffic="true" to <application
        if 'android:usesCleartextTraffic' not in manifest:
            manifest = manifest.replace('<application', '<application\n        android:usesCleartextTraffic="true"')

        # Ensure label is Settlr
        manifest = re.sub(r'android:label="[^"]*"', 'android:label="Settlr"', manifest)

        # Add FileProvider inside <application>
        provider_block = """
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
"""
        if 'androidx.core.content.FileProvider' not in manifest:
            manifest = manifest.replace('</application>', provider_block + '    </application>')

        with open(manifest_path, 'w', encoding='utf-8') as f:
            f.write(manifest)
        print("Successfully patched AndroidManifest.xml")

    # 4. Copy Release Keystore and configure build.gradle
    jks_src = os.path.join(assets_dir, 'settlr-release.jks')
    app_dir = os.path.join(android_dir, 'app')
    if os.path.exists(jks_src) and os.path.exists(app_dir):
        shutil.copy2(jks_src, os.path.join(app_dir, 'settlr-release.jks'))
        print("Copied settlr-release.jks to android/app/")

    # Patch build.gradle (Groovy) or build.gradle.kts (Kotlin)
    gradle_groovy = os.path.join(app_dir, 'build.gradle')
    gradle_kts = os.path.join(app_dir, 'build.gradle.kts')

    if os.path.exists(gradle_groovy):
        with open(gradle_groovy, 'r', encoding='utf-8') as f:
            content = f.read()

        signing_block = """
    signingConfigs {
        release {
            keyAlias 'settlr'
            keyPassword 'settlr123'
            storeFile file('settlr-release.jks')
            storePassword 'settlr123'
        }
    }
"""
        if 'signingConfigs {' not in content:
            content = re.sub(r'(android\s*\{)', r'\1' + signing_block, content, count=1)
        elif 'keyAlias \'settlr\'' not in content:
            content = content.replace('signingConfigs {', 'signingConfigs {\n        release {\n            keyAlias \'settlr\'\n            keyPassword \'settlr123\'\n            storeFile file(\'settlr-release.jks\')\n            storePassword \'settlr123\'\n        }\n')

        # Set signingConfig for release
        content = re.sub(
            r'buildTypes\s*\{\s*release\s*\{[^}]*\}',
            'buildTypes {\n        release {\n            signingConfig signingConfigs.release\n            minifyEnabled false\n            shrinkResources false\n        }',
            content
        )
        with open(gradle_groovy, 'w', encoding='utf-8') as f:
            f.write(content)
        print("Patched android/app/build.gradle with permanent release signingConfig")

    elif os.path.exists(gradle_kts):
        with open(gradle_kts, 'r', encoding='utf-8') as f:
            content = f.read()

        signing_block_kts = """
    signingConfigs {
        create("release") {
            keyAlias = "settlr"
            keyPassword = "settlr123"
            storeFile = file("settlr-release.jks")
            storePassword = "settlr123"
        }
    }
"""
        if 'signingConfigs {' not in content:
            content = re.sub(r'(android\s*\{)', r'\1' + signing_block_kts, content, count=1)
        # Set signingConfig for release in kts
        content = re.sub(
            r'buildTypes\s*\{\s*release\s*\{[^}]*\}',
            'buildTypes {\n        release {\n            signingConfig = signingConfigs.getByName("release")\n            isMinifyEnabled = false\n            isShrinkResources = false\n        }',
            content
        )
        with open(gradle_kts, 'w', encoding='utf-8') as f:
            f.write(content)
        print("Patched android/app/build.gradle.kts with permanent release signingConfig")

if __name__ == '__main__':
    patch_android_project()

