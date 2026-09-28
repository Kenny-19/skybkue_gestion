; ═══════════════════════════════════════════════════════════════════════
;  Skyblue — Installeur NSIS
;
;  Compile avec :
;    makensis /DAPP_VERSION=0.3.0 skyblue.nsi
;
;  Produit : skyblue-setup-<version>.exe
;
;  Emplacement d'installation : %LOCALAPPDATA%\Skyblue
;    → aucun droit admin requis, install et update transparents.
;
;  Ce que fait l'installeur :
;    1. Ferme l'app si elle tourne
;    2. Copie les fichiers Flutter (build/windows/x64/runner/Release/)
;    3. Crée raccourcis menu Démarrer + Bureau (optionnel)
;    4. Enregistre dans "Programmes et fonctionnalités" (uninstall propre)
;    5. NE TOUCHE PAS à Documents\BlueSky\blue_sky.db (les données)
;    6. Propose de relancer l'app à la fin
; ═══════════════════════════════════════════════════════════════════════

!ifndef APP_VERSION
  !define APP_VERSION "0.0.0"
!endif

!define APP_NAME       "Skyblue"
!define APP_PUBLISHER  "Afrinvest"
!define APP_URL        "https://skyblue-rdc.com"
!define APP_EXE        "blue_sky_ventes.exe"
!define APP_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Skyblue"

; ─── Métadonnées ──────────────────────────────────────────────────────
Name             "${APP_NAME} ${APP_VERSION}"
OutFile          "skyblue-setup-${APP_VERSION}.exe"
BrandingText     "${APP_NAME} — ${APP_PUBLISHER}"
Unicode          true
SetCompressor    /SOLID lzma
RequestExecutionLevel user   ; ← pas d'admin
InstallDir       "$LOCALAPPDATA\Skyblue"
InstallDirRegKey HKCU "${APP_UNINST_KEY}" "InstallLocation"

; VIProductVersion doit être MAJOR.MINOR.PATCH.BUILD (4 nombres).
; On extrait les 3 premiers de APP_VERSION et on ajoute .0.
VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey  "ProductName"     "${APP_NAME}"
VIAddVersionKey  "CompanyName"     "${APP_PUBLISHER}"
VIAddVersionKey  "FileDescription" "${APP_NAME} — Point de vente"
VIAddVersionKey  "FileVersion"     "${APP_VERSION}"
VIAddVersionKey  "ProductVersion"  "${APP_VERSION}"
VIAddVersionKey  "LegalCopyright"  "© ${APP_PUBLISHER}"

; ─── Modern UI + helpers ──────────────────────────────────────────────
!include "MUI2.nsh"
!include "FileFunc.nsh"   ; requis pour ${GetSize}

!define MUI_ABORTWARNING
!define MUI_ICON     "app_icon.ico"
!define MUI_UNICON   "app_icon.ico"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Lancer ${APP_NAME}"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "French"

; ─── Section principale ───────────────────────────────────────────────
Section "Skyblue (obligatoire)" SecMain
  SectionIn RO   ; non désélectionnable

  ; 1. Fermer l'app si elle tourne (sinon on ne peut pas remplacer .exe).
  DetailPrint "Fermeture de ${APP_NAME} s'il est en cours d'exécution..."
  nsExec::Exec 'taskkill /F /IM ${APP_EXE}'
  Sleep 500

  ; 2. Copier les fichiers Flutter (Release build).
  SetOutPath "$INSTDIR"
  File /r "..\build\windows\x64\runner\Release\*.*"

  ; 3. Raccourci menu Démarrer.
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut  "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" \
                  "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0
  CreateShortcut  "$SMPROGRAMS\${APP_NAME}\Désinstaller.lnk" \
                  "$INSTDIR\uninstall.exe"

  ; 4. Raccourci bureau (optionnel, souvent apprécié pour un POS).
  CreateShortcut  "$DESKTOP\${APP_NAME}.lnk" \
                  "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0

  ; 5. Uninstaller + enregistrement dans "Ajout/Suppression de programmes".
  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKCU "${APP_UNINST_KEY}" "DisplayName"     "${APP_NAME}"
  WriteRegStr HKCU "${APP_UNINST_KEY}" "DisplayVersion"  "${APP_VERSION}"
  WriteRegStr HKCU "${APP_UNINST_KEY}" "Publisher"       "${APP_PUBLISHER}"
  WriteRegStr HKCU "${APP_UNINST_KEY}" "URLInfoAbout"    "${APP_URL}"
  WriteRegStr HKCU "${APP_UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${APP_UNINST_KEY}" "DisplayIcon"     "$INSTDIR\${APP_EXE}"
  WriteRegStr HKCU "${APP_UNINST_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKCU "${APP_UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
  WriteRegDWORD HKCU "${APP_UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${APP_UNINST_KEY}" "NoRepair" 1

  ; Estimation de la taille pour Ajout/Suppression de programmes.
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "${APP_UNINST_KEY}" "EstimatedSize" "$0"
SectionEnd

; ─── Uninstaller ─────────────────────────────────────────────────────
; ATTENTION : ne supprime PAS Documents\BlueSky\blue_sky.db (les données).
; L'utilisateur doit expressément vider ce dossier s'il veut tout effacer.
Section "Uninstall"
  ; Fermer l'app avant de supprimer.
  nsExec::Exec 'taskkill /F /IM ${APP_EXE}'
  Sleep 500

  Delete   "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  Delete   "$SMPROGRAMS\${APP_NAME}\Désinstaller.lnk"
  RMDir    "$SMPROGRAMS\${APP_NAME}"
  Delete   "$DESKTOP\${APP_NAME}.lnk"

  ; Supprime tout le dossier d'install (fichiers Flutter + uninstall.exe).
  RMDir /r "$INSTDIR"

  DeleteRegKey HKCU "${APP_UNINST_KEY}"

  MessageBox MB_OK|MB_ICONINFORMATION \
    "Skyblue a été désinstallé.$\r$\n$\r$\nTes données restent dans :$\r$\n$DOCUMENTS\BlueSky\$\r$\nSupprime ce dossier manuellement si tu veux tout effacer."
SectionEnd
