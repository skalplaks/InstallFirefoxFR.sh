#!/bin/sh
#####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#	FirefoxInstall.sh -- Installs or updates Firefox with user approval via swiftDialog
#
# SYNOPSIS
#	sudo FirefoxInstall.sh
#
####################################################################################################
#
# HISTORY
#
#	Version: 1.6
#
#	  - Joe Farage, 18.03.2015 https://github.com/jamf/Jamf-Nation-Scripts/blob/175bbaa10af79f0aca6cb5e06eb8af130a6e3e8a/FirefoxInstall.sh#L7
#   - Modification pour support ARM et langue par défaut en français, verbosité augmentée
#   - Ajout de la confirmation de mise à jour via swiftDialog
#   - Ajout de sudo pour assurer les permissions nécessaires
#   - Remplacement de ditto par rsync pour éviter les problèmes de permission
#   - Ajout de la désinstallation de Firefox avant l'installation
####################################################################################################
# Script to download and install Firefox.
# Now supports Intel and ARM systems.
# User confirmation required via swiftDialog before proceeding with update.
#
# Choose language (en-US, fr, de)
lang="fr"  # Langue par défaut définie en français

echo "Démarrage du script d'installation/mise à jour de Firefox..."

# VÉRIFICATION SI UNE VALEUR A ÉTÉ PASSÉE EN PARAMÈTRE 4 ET, LE CAS ÉCHÉANT, ASSIGNER À "lang"
if [ -n "$4" ]; then  # Vérifie si $4 n'est pas vide
    lang="$4"
    echo "Paramètre de langue détecté, définition de la langue sur $lang"
else
    echo "Aucun paramètre de langue fourni. Utilisation de la langue par défaut : $lang"
fi

dmgfile="FF.dmg"
logfile="/Library/Logs/FirefoxInstallScript.log"

echo "Fichier de log : $logfile"
echo "Vérification de l'architecture du système..."

# Vérifie si nous sommes sur Intel ou ARM en utilisant uname -m
arch=$(uname -m)
echo "Architecture détectée : $arch"

if [ "$arch" = "i386" ] || [ "$arch" = "x86_64" ] || [ "$arch" = "arm64" ]; then
    echo "Architecture prise en charge : $arch"

    ## Obtenir la version du système d'exploitation et ajuster pour l'utilisation dans l'URL
    OSvers=$(sw_vers -productVersion)
    OSvers_URL=$(echo "$OSvers" | sed 's/[.]/_/g')
    echo "Version du système d'exploitation : $OSvers (format URL : $OSvers_URL)"

    ## Définir la chaîne User Agent pour utiliser avec curl
    userAgent="Mozilla/5.0 (Macintosh; ${arch} Mac OS X ${OSvers_URL}) AppleWebKit/535.6.2 (KHTML, like Gecko) Version/5.2 Safari/535.6.2"
    echo "User Agent défini pour curl : $userAgent"

    # Obtenir la dernière version de Firefox disponible depuis la page de Firefox
    echo "Récupération des informations de la dernière version de Firefox..."
    latestver=$(curl -s -A "$userAgent" "https://www.mozilla.org/${lang}/firefox/new/" | grep 'data-latest-firefox' | sed -e 's/.* data-latest-firefox="\(.*\)".*/\1/' -e 's/"//' | awk '{print $1}')
    echo "Dernière version disponible de Firefox : $latestver"

    # Obtenir le numéro de version de Firefox actuellement installé, le cas échéant
    if [ -e "/Applications/Firefox.app" ]; then
        currentinstalledver=$(defaults read /Applications/Firefox.app/Contents/Info CFBundleShortVersionString)
        echo "Version actuellement installée de Firefox : $currentinstalledver"
        if [ "${latestver}" = "${currentinstalledver}" ]; then
            echo "Firefox est à jour. Fin du script."
            exit 0
        fi
    else
        currentinstalledver="none"
        echo "Firefox n'est pas actuellement installé."
    fi

    # Demande de confirmation à l'utilisateur avant de continuer
    /usr/local/bin/dialog --title "Mise à jour de Firefox" --message "Une nouvelle version de Firefox est disponible. Souhaitez-vous mettre à jour maintenant ?

Attention : ceci redémarrera le navigateur" --icon "/usr/local/share/brandingimage.png" --button1text "Mettre à jour" --button2text "Annuler"
    user_choice=$?

    if [ "$user_choice" -ne 0 ]; then
        echo "Mise à jour annulée par l'utilisateur. Fin du script."
        echo "$(date): Mise à jour annulée par l'utilisateur." >> ${logfile}
        exit 0
    fi

    url="https://download-installer.cdn.mozilla.net/pub/firefox/releases/${latestver}/mac/${lang}/Firefox%20${latestver}.dmg"
    
    echo "URL de téléchargement de la dernière version : $url"
    echo "$(date): URL de téléchargement : $url" >> ${logfile}

    # Comparer les deux versions. Si elles sont différentes ou si Firefox n'est pas présent, télécharger et installer la nouvelle version.
    if [ "${currentinstalledver}" != "${latestver}" ]; then
        echo "Une nouvelle version de Firefox est disponible. Téléchargement et installation en cours..."
        echo "$(date): Version actuelle de Firefox : ${currentinstalledver}" >> ${logfile}
        echo "$(date): Version disponible de Firefox : ${latestver}" >> ${logfile}
        echo "$(date): Téléchargement de la nouvelle version..." >> ${logfile}
        curl -s -o /tmp/${dmgfile} ${url}
        echo "Téléchargement terminé. Montage de l'image disque..."
        echo "$(date): Montage de l'image disque d'installation." >> ${logfile}
        sudo hdiutil attach /tmp/${dmgfile} -nobrowse -quiet

        # Désinstaller la version actuelle de Firefox si elle est présente
        if [ -e "/Applications/Firefox.app" ]; then
            echo "$(date): Suppression de l'ancienne version de Firefox..." >> ${logfile}
            sudo rm -rf "/Applications/Firefox.app"
        fi

        echo "$(date): Installation de Firefox..." >> ${logfile}
        echo "Copie de Firefox dans le dossier Applications..."
        sudo rsync -a "/Volumes/Firefox/Firefox.app/" "/Applications/Firefox.app"
        
        sleep 10
        echo "Démontage de l'image disque..."
        echo "$(date): Démontage de l'image disque d'installation." >> ${logfile}
        sudo hdiutil detach $(df | grep Firefox | awk '{print $1}') -quiet
        sleep 10
        echo "Suppression du fichier d'image disque temporaire..."
        echo "$(date): Suppression de l'image disque." >> ${logfile}
        sudo rm /tmp/${dmgfile}
        
        # Vérifier si la nouvelle version a été installée
        newlyinstalledver=$(defaults read /Applications/Firefox.app/Contents/Info CFBundleShortVersionString)
        if [ "${latestver}" = "${newlyinstalledver}" ]; then
            echo "$(date): SUCCESS: Firefox a été mis à jour à la version ${newlyinstalledver}" >> ${logfile}
            echo "SUCCESS : Firefox a été mis à jour à la version ${newlyinstalledver}"
        else
            echo "$(date): ERROR: Mise à jour de Firefox échouée, la version reste à ${currentinstalledver}." >> ${logfile}
            echo "ERREUR : Mise à jour de Firefox échouée, la version reste à ${currentinstalledver}."
            echo "--" >> ${logfile}
            exit 1
        fi
    # Si Firefox est déjà à jour, enregistrer et quitter.
    else
        echo "$(date): Firefox est déjà à jour, version actuelle : ${currentinstalledver}." >> ${logfile}
        echo "Firefox est déjà à jour, version actuelle : ${currentinstalledver}."
        echo "--" >> ${logfile}
    fi    
else
    echo "ERREUR : Architecture système non prise en charge. Ce script est destiné uniquement aux Mac Intel et ARM."
    echo "$(date): ERREUR : Architecture système non prise en charge. Ce script est destiné uniquement aux Mac Intel et ARM." >> ${logfile}
fi

exit 0
