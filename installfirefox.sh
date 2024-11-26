#!/bin/sh
#####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#   FirefoxESRInstall.sh -- Installs or updates Firefox ESR with user approval via swiftDialog
#
# SYNOPSIS
#   sudo FirefoxESRInstall.sh
#
####################################################################################################
#
# HISTORY
#
#   Version: 1.9.2
#
#   - DJELAL Oussama, 2024-11-25
#   - Fixed version extraction issue to ensure the correct Firefox ESR version without "esr" suffix.
#
####################################################################################################
# Script to download and install Firefox ESR.
# Now supports Intel and ARM systems.
# User confirmation required via swiftDialog before proceeding with update.
#
# Choose language (en-US, fr, de, etc.)
lang="fr"  # Langue par défaut définie en français

echo "Démarrage du script d'installation/mise à jour de Firefox ESR..."

# VÉRIFICATION SI UNE VALEUR A ÉTÉ PASSÉE EN PARAMÈTRE 4 ET, LE CAS ÉCHÉANT, ASSIGNER À "lang"
if [ -n "$4" ]; then  # Vérifie si $4 n'est pas vide
    lang="$4"
    echo "Paramètre de langue détecté, définition de la langue sur $lang"
else
    echo "Aucun paramètre de langue fourni. Utilisation de la langue par défaut : $lang"
fi

dmgfile="FFESR.dmg"
logfile="/Library/Logs/FirefoxESRInstallScript.log"

echo "Fichier de log : $logfile"
echo "Vérification de l'architecture du système..."

# Vérifie si nous sommes sur Intel ou ARM en utilisant uname -m
arch=$(/usr/bin/uname -m)
echo "Architecture détectée : $arch"

if [ "$arch" = "i386" ] || [ "$arch" = "x86_64" ] || [ "$arch" = "arm64" ]; then
    echo "Architecture prise en charge : $arch"

    ## Obtenir la version du système d'exploitation et ajuster pour l'utilisation dans l'URL
    OSvers=$(sw_vers -productVersion)
    if [ -z "$OSvers" ]; then
        echo "Erreur : Impossible de déterminer la version du système d'exploitation."
        echo "$(date): ERREUR : Impossible de déterminer la version du système d'exploitation." >> "${logfile}"
        exit 1
    fi
    OSvers_URL=$(echo "$OSvers" | sed 's/[.]/_/g')
    echo "Version du système d'exploitation : $OSvers (format URL : $OSvers_URL)"

    ## Définir la chaîne User Agent pour utiliser avec curl
    userAgent="Mozilla/5.0 (Macintosh; ${arch} Mac OS X ${OSvers_URL}) AppleWebKit/535.6.2 (KHTML, like Gecko) Version/5.2 Safari/535.6.2"
    echo "User Agent défini pour curl : $userAgent"

    # Obtenir la dernière version ESR de Firefox disponible depuis la page de téléchargement JSON de Mozilla
    echo "Récupération des informations de la dernière version ESR de Firefox..."
    latestver=$(curl -s -A "$userAgent" "https://product-details.mozilla.org/1.0/firefox_versions.json" | grep '"FIREFOX_ESR"' | sed -e 's/.*: "\([0-9.]*\)esr".*/\1/')

    if [ -z "$latestver" ]; then
        echo "Erreur : Impossible de récupérer la version de Firefox ESR."
        echo "$(date): ERREUR : Impossible de récupérer la version de Firefox ESR." >> "${logfile}"
        exit 1
    fi

    echo "Dernière version ESR disponible de Firefox : $latestver"

    # Obtenir le numéro de version de Firefox actuellement installé, le cas échéant
    if [ -e "/Applications/Firefox.app" ]; then
        currentinstalledver=$(/usr/bin/defaults read /Applications/Firefox.app/Contents/Info CFBundleShortVersionString 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$currentinstalledver" ]; then
            currentinstalledver="none"
            echo "Firefox n'est pas correctement installé ou la version ne peut être déterminée."
            echo "$(date): Firefox n'est pas correctement installé ou la version ne peut être déterminée." >> "${logfile}"
        else
            echo "Version actuellement installée de Firefox : $currentinstalledver"
        fi
    else
        currentinstalledver="none"
        echo "Firefox n'est pas actuellement installé."
        echo "$(date): Firefox n'est pas actuellement installé." >> "${logfile}"
    fi

    # Comparer les deux versions. Si elles sont différentes ou si Firefox n'est pas présent, demander la confirmation à l'utilisateur et télécharger et installer la nouvelle version.
    if [ "$currentinstalledver" = "$latestver" ]; then
        echo "Firefox ESR est déjà à jour, version actuelle : ${currentinstalledver}."
        echo "$(date): Firefox ESR est déjà à jour, version actuelle : ${currentinstalledver}." >> "${logfile}"
        exit 0
    fi

    if [ "$currentinstalledver" = "none" ] || [ "$currentinstalledver" != "$latestver" ]; then
        # Demande de confirmation à l'utilisateur avant de continuer
        /usr/local/bin/dialog --title "Mise à jour de Firefox ESR" --message "Une nouvelle version de Firefox ESR est disponible. Souhaitez-vous mettre à jour maintenant ?

Attention : ceci redémarrera votre navigateur." --icon "/usr/local/share/brandingimage.png" --button1text "Mettre à jour" --button2text "Annuler"
        user_choice=$?

        if [ "$user_choice" -ne 0 ]; then
            echo "Mise à jour annulée par l'utilisateur. Fin du script."
            echo "$(date): Mise à jour annulée par l'utilisateur." >> ${logfile}
            exit 0
        fi

        /bin/sleep 5

        # Assurer que Firefox est fermé avant de désinstaller
        echo "Vérification et fermeture de Firefox s'il est en cours d'exécution..."
        sudo /usr/bin/osascript -e 'tell application "Firefox" to quit'
        /bin/sleep 5
        /usr/bin/pgrep Firefox && sudo /usr/bin/pkill -9 Firefox
        if [ $? -eq 0 ]; then
            echo "Firefox fermé avec succès."
            echo "$(date): Firefox fermé avant la désinstallation." >> "${logfile}"
        fi

        # Si Firefox est déjà installé, le supprimer
        if [ -d "/Applications/Firefox.app" ]; then
            echo "Suppression de la version actuelle de Firefox..."
            sudo /bin/rm -rf "/Applications/Firefox.app"
            if [ $? -eq 0 ]; then
                echo "Firefox supprimé avec succès."
                echo "$(date): Firefox supprimé avant la nouvelle installation." >> "${logfile}"
            else
                echo "Erreur : Échec de la suppression de Firefox."
                echo "$(date): ERREUR : Échec de la suppression de Firefox." >> "${logfile}"
                exit 1
            fi
        fi

        url="https://download-installer.cdn.mozilla.net/pub/firefox/releases/${latestver}esr/mac/${lang}/Firefox%20${latestver}esr.dmg"
        
        echo "URL de téléchargement de la dernière version : $url"
        echo "$(date): URL de téléchargement : $url" >> "${logfile}"

        echo "Téléchargement et installation de Firefox ESR en cours..."
        
        /usr/bin/curl -s -L -A "$userAgent" -o /tmp/"${dmgfile}" "${url}"
        
        if [ $? -ne 0 ]; then
            echo "Erreur : Échec du téléchargement de Firefox ESR."
            echo "$(date): ERREUR : Échec du téléchargement de Firefox ESR." >> "${logfile}"
            exit 1
        fi
        
        echo "Téléchargement terminé. Montage de l'image disque..."
        echo "$(date): Montage de l'image disque d'installation." >> "${logfile}"
        
        /usr/bin/hdiutil attach /tmp/"${dmgfile}" -nobrowse -quiet
        if [ $? -ne 0 ]; then
            echo "Erreur : Échec du montage de l'image disque."
            echo "$(date): ERREUR : Échec du montage de l'image disque." >> "${logfile}"
            /bin/rm /tmp/"${dmgfile}"
            exit 1
        fi
        
        echo "Installation de Firefox ESR..."
        echo "$(date): Installation de Firefox ESR..." >> "${logfile}"
        echo "Copie de Firefox dans le dossier Applications..."
        
        sudo rsync -a --delete "/Volumes/Firefox/Firefox.app/" "/Applications/Firefox.app/"
        if [ $? -ne 0 ]; then
            echo "Erreur : Échec de la copie de Firefox dans Applications."
            echo "$(date): ERREUR : Échec de la copie de Firefox dans Applications." >> "${logfile}"
            /usr/bin/hdiutil detach "/Volumes/Firefox" -quiet
            /bin/rm /tmp/"${dmgfile}"
            exit 1
        fi
        
        /bin/sleep 10
        echo "Démontage de l'image disque..."
        echo "$(date): Démontage de l'image disque d'installation." >> "${logfile}"
        /usr/bin/hdiutil detach "/Volumes/Firefox" -quiet
        if [ $? -ne 0 ]; then
            echo "Erreur : Échec du démontage de l'image disque."
            echo "$(date): ERREUR : Échec du démontage de l'image disque." >> "${logfile}"
            /bin/rm /tmp/"${dmgfile}"
            exit 1
        fi
        
        /bin/sleep 10
        echo "Suppression du fichier d'image disque temporaire..."
        echo "$(date): Suppression de l'image disque." >> "${logfile}"
        /bin/rm /tmp/"${dmgfile}"
        
        # Vérifier si la nouvelle version a été installée
        newlyinstalledver=$(/usr/bin/defaults read /Applications/Firefox.app/Contents/Info CFBundleShortVersionString 2>/dev/null)
        if [ "$latestver" = "$newlyinstalledver" ]; then
            echo "SUCCESS : Firefox ESR a été mis à jour à la version ${newlyinstalledver}"
            echo "$(date): SUCCESS: Firefox ESR a été mis à jour à la version ${newlyinstalledver}" >> "${logfile}"
            /usr/local/bin/dialog --title "Installation réussie" --message "Firefox ESR a été mis à jour avec succès à la version ${newlyinstalledver}." --button1text "OK"
        else
            echo "ERREUR : Mise à jour de Firefox ESR échouée, la version reste à ${currentinstalledver}."
            echo "$(date): ERREUR: Mise à jour de Firefox ESR échouée, la version reste à ${currentinstalledver}." >> "${logfile}"
            echo "--" >> "${logfile}"
            /usr/local/bin/dialog --title "Échec de l'installation" --message "La mise à jour de Firefox ESR a échoué. La version actuelle reste ${currentinstalledver}." --button1text "OK"
            exit 1
        fi
    fi    
else
    echo "ERREUR : Architecture système non prise en charge. Ce script est destiné uniquement aux Mac Intel et ARM."
    echo "$(date): ERREUR : Architecture système non prise en charge. Ce script est destiné uniquement aux Mac Intel et ARM." >> "${logfile}"
    /usr/local/bin/dialog --title "Erreur d'installation" --message "Architecture système non prise en charge. Ce script est destiné uniquement aux Mac Intel et ARM." --button1text "OK"
fi

exit 0
