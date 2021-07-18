EnableExplicit

Define.s workingDirectory = GetPathPart(ProgramFilename())
Global.s tempDirectory = GetTemporaryDirectory()

Global Dim programFilesDir.s(1)
Global.i downloadOkButton
Global.i downloadThread
Global.i downloadThreadsAmount
Global.i asyncDownload
Global.i versionsGadget, playButton, javaListGadget, deleteVersionButton
Global.i progressBar, filesLeft, progressWindow, downloadingClientTextGadget
Global.i versionsDownloadGadget, downloadVersionButton
Global.i forceDownloadMissingLibraries
Global.s versionsManifestString

Define *FileBuffer

Define.i Event, font, ramGadget, nameGadget, javaPathGadget, argsGadget, downloadButton, settingsButton, launcherVersionGadget, launcherAuthorGadget
Define.i saveLaunchString, versionsTypeGadget, saveLaunchStringGadget, launchStringFile, inheritsJsonObject, jsonInheritsArgumentsModernMember
Define.i argsTextGadget, javaBinaryPathTextGadget, downloadThreadsTextGadget, downloadAllFilesGadget, javaPathGadget
Define.i gadgetsWidth, gadgetsHeight, gadgetsIndent, windowWidth, windowHeight
Define.i listOfFiles, jsonFile, jsonObject, jsonObjectObjects, fileSize, jsonJarMember, jsonArgumentsArray, jsonArrayElement, inheritsJson, clientSize
Define.i versionSecondDigit, PID

Define.s playerName, ramAmount, clientVersion, javaBinaryPath, fullLaunchString, assetsIndex, clientUrl, fileHash, versionToDownload
Define.s assetsIndex, clientMainClass, clientArguments, inheritsClientJar, customLaunchArguments, clientJarFile, nativesPath, librariesString
Define.s uuid

Define.i downloadMissingLibraries, jsonArgumentsMember, jsonArgumentsModernMember, jsonInheritsFromMember
Define.i downloadMissingLibrariesGadget, downloadThreadsGadget, asyncDownloadGadget, saveSettingsButton, useCustomJavaGadget, useCustomParamsGadget, keepLauncherOpenGadget
Define.i i

Define.s playerNameDefault = "Name", ramAmountDefault = "700"
Define.s customLaunchArgumentsDefault = "-Xss1M -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M"
Define.s customOldLaunchArgumentsDefault = "-XX:+UseConcMarkSweepGC -XX:+CMSIncrementalMode -XX:-UseAdaptiveSizePolicy -Xmn128M"
Define.i downloadThreadsAmountDefault = 10
Define.i asyncDownloadDefault = 0
Define.i downloadMissingLibrariesDefault = 0
Define.i downloadAllFilesDefault = 0
Define.i versionsTypeDefault = 0
Define.i saveLaunchStringDefault = 0
Define.i useCustomParamsDefault = 0
Define.i keepLauncherOpenDefault = 0
Global.i useCustomJavaDefault = 0
Global.s javaBinaryPathDefault = "C:\jre8\bin\javaw.exe"

Define.s launcherVersion = "1.1.14"
Define.s launcherDeveloper = "Kron(4ek)"

Declare assetsToResources(assetsIndex.s)
Declare findJava()
Declare progressWindow(clientVersion.s)
Declare findInstalledVersions()
Declare downloadFiles(downloadAllFiles.i)
Declare CreateDirectoryRecursive(path.s)

Declare showLaunchErrors(PID.i)

Declare.s parseVersionsManifest(versionType.i = 0, getClientJarUrl.i = 0, clientVersion.s = "")
Declare.s parseLibraries(clientVersion.s, prepareForDownload.i = 0)
Declare.s fileRead(pathToFile.s)
Declare.s removeSpacesFromVersionName(clientVersion.s)

IncludeFile "functions.pb"

programFilesDir(0) = GetEnvironmentVariable("ProgramW6432") + "\"
programFilesDir(1) = GetEnvironmentVariable("PROGRAMFILES") + "\"

SetCurrentDirectory(workingDirectory)
OpenPreferences("vortex_launcher.conf")

downloadThreadsAmount = ReadPreferenceInteger("DownloadThreads", downloadThreadsAmountDefault)
asyncDownload = ReadPreferenceInteger("AsyncDownload", asyncDownloadDefault)

DeleteFile(tempDirectory + "vlauncher_download_list.txt")

RemoveEnvironmentVariable("_JAVA_OPTIONS")

windowWidth = 250
windowHeight = 295

If OpenWindow(0, #PB_Ignore, #PB_Ignore, windowWidth, windowHeight, "Vortex Minecraft Launcher")

  gadgetsWidth = windowWidth - 10
  gadgetsHeight = 25
  gadgetsIndent = 5

  nameGadget = StringGadget(#PB_Any, gadgetsIndent, 5, gadgetsWidth, gadgetsHeight, ReadPreferenceString("Name", playerNameDefault))
  SetGadgetAttribute(nameGadget, #PB_String_MaximumLength, 16)

  ramGadget = StringGadget(#PB_Any, gadgetsIndent, 35, gadgetsWidth, gadgetsHeight, ReadPreferenceString("Ram", ramAmountDefault), #PB_String_Numeric)
  GadgetToolTip(ramGadget, "Amount (megabytes) of memory to allocate for Minecraft")
  SetGadgetAttribute(ramGadget, #PB_String_MaximumLength, 6)

  versionsGadget = ComboBoxGadget(#PB_Any, gadgetsIndent, 65, gadgetsWidth, gadgetsHeight)
  deleteVersionButton = ButtonGadget(#PB_Any, gadgetsIndent, 92, gadgetsWidth, gadgetsHeight, "Delete this version")
  javaListGadget = ComboBoxGadget(#PB_Any, gadgetsIndent, 135, gadgetsWidth, gadgetsHeight)

  playButton = ButtonGadget(#PB_Any, gadgetsIndent, 165, gadgetsWidth, gadgetsHeight + 5, "Play")
  downloadButton = ButtonGadget(#PB_Any, gadgetsIndent, 200, gadgetsWidth, gadgetsHeight + 5, "Downloader")
  settingsButton = ButtonGadget(#PB_Any, gadgetsIndent, 235, gadgetsWidth, gadgetsHeight + 5, "Settings")

  If LoadFont(0, "Arial", 10, #PB_Font_Bold)
    SetGadgetFont(playButton, FontID(0))
    SetGadgetFont(downloadButton, FontID(0))
  EndIf

  launcherAuthorGadget = TextGadget(#PB_Any, 2, windowHeight - 10, 70, 20, "by " + launcherDeveloper)
  launcherVersionGadget = TextGadget(#PB_Any, windowWidth - 34, windowHeight - 10, 50, 20, "v" + launcherVersion)
  If LoadFont(1, "Arial", 7)
    font = FontID(1) : SetGadgetFont(launcherAuthorGadget, font) : SetGadgetFont(launcherVersionGadget, font)
  EndIf

  findInstalledVersions()
  findJava()

  Repeat
    Event = WaitWindowEvent()

    If Event = #PB_Event_Gadget
      Select EventGadget()
        Case playButton
          ramAmount = GetGadgetText(ramGadget)
          clientVersion = GetGadgetText(versionsGadget)
          playerName = GetGadgetText(nameGadget)
          javaBinaryPath = GetGadgetText(javaListGadget)
          downloadMissingLibraries = ReadPreferenceInteger("DownloadMissingLibs", downloadMissingLibrariesDefault)
          versionSecondDigit = Val(StringField(clientVersion, 2, "."))
          librariesString = ""
          clientArguments = ""

          If versionSecondDigit < 13
            customLaunchArguments = customOldLaunchArgumentsDefault
          Else
            customLaunchArguments = customLaunchArgumentsDefault
          EndIf

          If FindString(clientVersion, " ")
            clientVersion = removeSpacesFromVersionName(clientVersion)
          EndIf

          If forceDownloadMissingLibraries
            downloadMissingLibraries = 1
          EndIf

          If FindString(playerName, " ")
            playerName = ReplaceString(playerName, " ", "")
          EndIf

          If ReadPreferenceInteger("UseCustomParameters", useCustomParamsDefault)
            customLaunchArguments = ReadPreferenceString("LaunchArguments", customLaunchArgumentsDefault)
          EndIf

          If ramAmount And Len(playerName) >= 3
            If ReadPreferenceInteger("UseCustomJava", useCustomJavaDefault)
              javaBinaryPath = ReadPreferenceString("JavaPath", javaBinaryPathDefault)
            ElseIf Right(javaBinaryPath, 5) = "(x32)"
              javaBinaryPath = programFilesDir(1) + "Java\" + RemoveString(javaBinaryPath, " (x32)") + "\bin\javaw.exe"
            Else
              javaBinaryPath = programFilesDir(0) + "Java\" + javaBinaryPath + "\bin\javaw.exe"
            EndIf

            If Val(ramAmount) < 350
              ramAmount = "350"

              MessageRequester("Warning", "You allocated too low amount of memory!" + #CRLF$ + #CRLF$ + "Allocated memory set to 350 MB to prevent crashes.")
            EndIf

            WritePreferenceString("Name", playerName)
            WritePreferenceString("Ram", ramAmount)
            WritePreferenceString("ChosenVer", clientVersion)

            If RunProgram(javaBinaryPath, "-version", workingDirectory)
              jsonFile = ParseJSON(#PB_Any, fileRead("versions\" + clientVersion + "\" + clientVersion + ".json"))

              If jsonFile
                jsonObject = JSONValue(jsonFile)

                jsonJarMember = GetJSONMember(jsonObject, "jar")
                jsonInheritsFromMember = GetJSONMember(jsonObject, "inheritsFrom")

                If jsonJarMember
                  clientJarFile = GetJSONString(jsonJarMember)
                  clientJarFile = "versions\" + clientJarFile + "\" + clientJarFile + ".jar"
                ElseIf jsonInheritsFromMember
                  inheritsClientJar = GetJSONString(jsonInheritsFromMember)

                  clientJarFile = "versions\" + inheritsClientJar + "\" + inheritsClientJar + ".jar"
                ElseIf FileSize("versions\" + clientVersion + "\" + clientVersion + ".jar") > 0
                  clientJarFile = "versions\" + clientVersion + "\" + clientVersion + ".jar"
                EndIf

                nativesPath = "versions\" + StringField(clientJarFile, 2, "\") + "\natives"

                jsonArgumentsMember = GetJSONMember(jsonObject, "minecraftArguments")
                jsonArgumentsModernMember = GetJSONMember(jsonObject, "arguments")

                If jsonArgumentsMember
                  clientArguments = GetJSONString(jsonArgumentsMember)
                ElseIf jsonArgumentsModernMember
                  jsonArgumentsArray = GetJSONMember(jsonArgumentsModernMember, "game")

                  For i = 0 To JSONArraySize(jsonArgumentsArray) - 1
                    jsonArrayElement = GetJSONElement(jsonArgumentsArray, i)

                    If JSONType(jsonArrayElement) = #PB_JSON_String
                      clientArguments + " " + GetJSONString(jsonArrayElement) + " "
                    EndIf
                  Next
                EndIf

                If jsonInheritsFromMember
                  inheritsClientJar = GetJSONString(jsonInheritsFromMember)

                  inheritsJson = ParseJSON(#PB_Any, fileRead("versions\" + inheritsClientJar + "\" + inheritsClientJar + ".json"))

                  If inheritsJson
                    inheritsJsonObject = JSONValue(inheritsJson)
                    jsonInheritsArgumentsModernMember = GetJSONMember(inheritsJsonObject, "arguments")

                    If jsonInheritsArgumentsModernMember
                      jsonArgumentsArray = GetJSONMember(jsonInheritsArgumentsModernMember, "game")

                      For i = 0 To JSONArraySize(jsonArgumentsArray) - 1
                        jsonArrayElement = GetJSONElement(jsonArgumentsArray, i)

                        If JSONType(jsonArrayElement) = #PB_JSON_String
                          clientArguments + " " + GetJSONString(jsonArrayElement) + " "
                        EndIf
                      Next
                    EndIf

                    librariesString + parseLibraries(inheritsClientJar, downloadMissingLibraries)
                    assetsIndex = GetJSONString(GetJSONMember(JSONValue(inheritsJson), "assets"))

                    FreeJSON(inheritsJson)
                  Else
                    MessageRequester("Error", inheritsClientJar + ".json file is missing!") : Break
                  EndIf
                Else
                  If GetJSONMember(jsonObject, "assets")
                    assetsIndex = GetJSONString(GetJSONMember(jsonObject, "assets"))
                  ElseIf versionSecondDigit < 6
                    assetsIndex = "pre-1.6"
                  Else
                    assetsIndex = "legacy"
                  EndIf
                EndIf

                If FileSize(clientJarFile) > 0
                  librariesString = parseLibraries(clientVersion, downloadMissingLibraries) + librariesString
                  clientMainClass = GetJSONString(GetJSONMember(jsonObject, "mainClass"))

                  UseMD5Fingerprint()

                  uuid = StringFingerprint("OfflinePlayer:" + playerName, #PB_Cipher_MD5)
                  uuid = Left(uuid, 12) + LCase(Hex(Val("$" + Mid(uuid, 13, 2)) & $0f | $30)) + Mid(uuid, 15, 2) + LCase(Hex(Val("$" + Mid(uuid, 17, 2)) & $3f | $80)) + Right(uuid, 14)

                  clientArguments = ReplaceString(clientArguments, "${auth_player_name}", playerName)
                  clientArguments = ReplaceString(clientArguments, "${version_name}", clientVersion)
                  clientArguments = ReplaceString(clientArguments, "${game_directory}", workingDirectory)
                  clientArguments = ReplaceString(clientArguments, "${assets_root}", "assets")
                  clientArguments = ReplaceString(clientArguments, "${auth_uuid}", uuid)
                  clientArguments = ReplaceString(clientArguments, "${auth_access_token}", "00000000000000000000000000000000")
                  clientArguments = ReplaceString(clientArguments, "${user_properties}", "{}")
                  clientArguments = ReplaceString(clientArguments, "${user_type}", "mojang")
                  clientArguments = ReplaceString(clientArguments, "${version_type}", "release")
                  clientArguments = ReplaceString(clientArguments, "${assets_index_name}", assetsIndex)
                  clientArguments = ReplaceString(clientArguments, "${auth_session}", "00000000000000000000000000000000")
                  clientArguments = ReplaceString(clientArguments, "${game_assets}", "resources")
                  clientArguments = ReplaceString(clientArguments, "  ", " ")

                  If assetsIndex = "pre-1.6" Or assetsIndex = "legacy"
                    assetsToResources(assetsIndex)
                  EndIf

                  If downloadMissingLibraries
                    downloadFiles(0)
                  EndIf

                  fullLaunchString = "-Xmx" + ramAmount + "M " + customLaunchArguments + " " + Chr(34) + "-Djava.library.path=" + nativesPath + Chr(34) + " -cp " + Chr(34) + librariesString + clientJarFile + Chr(34) + " " + clientMainClass + " " + clientArguments
                  PID = RunProgram(javaBinaryPath, fullLaunchString, workingDirectory,#PB_Program_Open | #PB_Program_Error)
                  
                  showLaunchErrors(PID)

                  saveLaunchString = ReadPreferenceInteger("SaveLaunchString", saveLaunchStringDefault)
                  If saveLaunchString
                    DeleteFile("launch_string.txt")

                    launchStringFile = OpenFile(#PB_Any, "launch_string.txt")
                    WriteString(launchStringFile, Chr(34) + javaBinaryPath + Chr(34) + " " + fullLaunchString)
                    CloseFile(launchStringFile)
                  EndIf

                  If Not ReadPreferenceInteger("KeepLauncherOpen", keepLauncherOpenDefault)
                    Break
                  EndIf
                Else
                  MessageRequester("Error", "Client jar file is missing!")
                EndIf

                FreeJSON(jsonFile)
              Else
                MessageRequester("Error", "Client json file is missing!")
              EndIf
            Else
              MessageRequester("Error", "Java not found! Check if Java installed." + #CRLF$ + #CRLF$ + "Or check if path to Java binary is correct.")
            EndIf
          Else
            If playerName = ""
              MessageRequester("Error", "Enter your desired name.")
            ElseIf ramAmount = ""
              MessageRequester("Error", "Enter RAM amount.")
            ElseIf Len(playerName) < 3
              MessageRequester("Error", "Name is too short! Minimum length is 3.")
            EndIf
          EndIf
        Case deleteVersionButton
          clientVersion = GetGadgetText(versionsGadget)
          MessageRequester("Delete", "Folder 'versions\" + clientVersion + "' deleted.")
          DeleteDirectory("versions\" + clientVersion, "*.*", #PB_FileSystem_Recursive)
          ClearGadgetItems(versionsGadget)
          findInstalledVersions()
        Case downloadButton
          InitNetwork()

          *FileBuffer = ReceiveHTTPMemory("https://launchermeta.mojang.com/mc/game/version_manifest.json")
          If *FileBuffer
            If OpenWindow(1, #PB_Ignore, #PB_Ignore, 200, 120, "Client Downloader")
              DisableGadget(downloadButton, 1)

              ComboBoxGadget(325, 5, 5, 190, 25)
              versionsDownloadGadget = 325
              CheckBoxGadget(110, 5, 40, 130, 20, "Show all versions")
              versionsTypeGadget = 110
              SetGadgetState(versionsTypeGadget, ReadPreferenceInteger("ShowAllVersions", versionsTypeDefault))
              CheckBoxGadget(817, 5, 60, 130, 20, "Redownload all files")
              downloadAllFilesGadget = 817
              SetGadgetState(downloadAllFilesGadget, ReadPreferenceInteger("RedownloadFiles", downloadAllFilesDefault))
              downloadVersionButton = ButtonGadget(#PB_Any, 5, 85, 190, 30, "Download")

              If IsThread(downloadThread) : DisableGadget(downloadVersionButton, 1) : EndIf

              versionsManifestString = PeekS(*FileBuffer, MemorySize(*FileBuffer), #PB_UTF8)
              FreeMemory(*FileBuffer)

              parseVersionsManifest(GetGadgetState(versionsTypeGadget))
            EndIf
          Else
            MessageRequester("Download Error", "Seems like you have no internet connection")
          EndIf
        Case versionsTypeGadget
          ClearGadgetItems(versionsDownloadGadget)
          parseVersionsManifest(GetGadgetState(versionsTypeGadget))
        Case downloadVersionButton
          versionToDownload = GetGadgetText(versionsDownloadGadget)

          CreateDirectoryRecursive("versions\" + versionToDownload)

          If ReceiveHTTPFile(parseVersionsManifest(GetGadgetState(versionsDownloadGadget), 1, versionToDownload), "versions\" + versionToDownload + "\" + versionToDownload + ".json")
            DeleteFile(tempDirectory + "vlauncher_download_list.txt")
            listOfFiles = OpenFile(#PB_Any, tempDirectory + "vlauncher_download_list.txt")

            jsonFile = ParseJSON(#PB_Any, fileRead("versions\" + versionToDownload + "\" + versionToDownload + ".json"))

            If jsonFile
              jsonObject = JSONValue(jsonFile)

              assetsIndex = GetJSONString(GetJSONMember(jsonObject, "assets"))

              CreateDirectoryRecursive("assets\indexes")
              ReceiveHTTPFile(GetJSONString(GetJSONMember(GetJSONMember(jsonObject, "assetIndex"), "url")), "assets\indexes\" + assetsIndex + ".json")

              clientUrl = GetJSONString(GetJSONMember(GetJSONMember(GetJSONMember(jsonObject, "downloads"), "client"), "url"))
              clientSize = GetJSONInteger(GetJSONMember(GetJSONMember(GetJSONMember(jsonObject, "downloads"), "client"), "size"))

              WriteStringN(listOfFiles, clientUrl + "::" + "versions\" + versionToDownload + "\" + versionToDownload + ".jar" + "::" + clientSize)

              FreeJSON(jsonFile)
            EndIf

            jsonFile = ParseJSON(#PB_Any, fileRead("assets\indexes\" + assetsIndex + ".json"))

            If jsonFile
              jsonObject = JSONValue(jsonFile)
              jsonObjectObjects = GetJSONMember(jsonObject, "objects")

              If ExamineJSONMembers(jsonObjectObjects)
                While NextJSONMember(jsonObjectObjects)
                  fileHash = GetJSONString(GetJSONMember(GetJSONMember(jsonObjectObjects, JSONMemberKey(jsonObjectObjects)), "hash"))
                  fileSize = GetJSONInteger(GetJSONMember(GetJSONMember(jsonObjectObjects, JSONMemberKey(jsonObjectObjects)), "size"))

                  WriteStringN(listOfFiles, "http://resources.download.minecraft.net/" + Left(fileHash, 2) + "/" + fileHash + "::" + "assets\objects\" + Left(fileHash, 2) + "\" + fileHash + "::" + fileSize)
                Wend
              EndIf

              FreeJSON(jsonFile)
            EndIf

            CloseFile(listOfFiles)

            parseLibraries(versionToDownload, 1)

            DisableGadget(playButton, 1)
            progressWindow(versionToDownload)

            downloadThread = CreateThread(@downloadFiles(), GetGadgetState(downloadAllFilesGadget))
          Else
            MessageRequester("Download Error", "Seems like you have no internet connection!")
          EndIf
        Case settingsButton
          DisableGadget(settingsButton, 1)

          If OpenWindow(3, #PB_Ignore, #PB_Ignore, 335, 255, "Vortex Launcher Settings")
              argsTextGadget = TextGadget(#PB_Any, 5, 5, 80, 30, "Launch parameters:")
              argsGadget = StringGadget(#PB_Any, 70, 5, 260, 25, ReadPreferenceString("LaunchArguments", customLaunchArgumentsDefault))
              GadgetToolTip(argsGadget, "These parameters will be used to launch Minecraft")

              javaBinaryPathTextGadget = TextGadget(#PB_Any, 5, 35, 80, 30, "Custom Java path:")
              javaPathGadget = StringGadget(#PB_Any, 70, 35, 260, 25, ReadPreferenceString("JavaPath", javaBinaryPathDefault))
              GadgetToolTip(javaPathGadget, "Absolute path to Java executable")

              downloadThreadsTextGadget = TextGadget(#PB_Any, 5, 65, 80, 30, "Download threads:")
              downloadThreadsGadget = StringGadget(#PB_Any, 70, 65, 260, 25, ReadPreferenceString("DownloadThreads", Str(downloadThreadsAmountDefault)), #PB_String_Numeric)
              GadgetToolTip(downloadThreadsGadget, "Higher numbers may speedup downloads (works only with multi-threads downloads)")
              SetGadgetAttribute(downloadThreadsGadget, #PB_String_MaximumLength, 3)

              CheckBoxGadget(311, 5, 95, 300, 20, "Fast multi-thread downloads (experimental)")
              asyncDownloadGadget = 311
              SetGadgetState(asyncDownloadGadget, ReadPreferenceInteger("AsyncDownload", asyncDownloadDefault))

              downloadMissingLibrariesGadget = CheckBoxGadget(#PB_Any, 5, 115, 300, 20, "Download missing libraries on game start")
              SetGadgetState(downloadMissingLibrariesGadget, ReadPreferenceInteger("DownloadMissingLibs", downloadMissingLibrariesDefault))

              saveLaunchStringGadget = CheckBoxGadget(#PB_Any, 5, 135, 300, 20, "Save launch string to file")
              GadgetToolTip(saveLaunchStringGadget, "Full launch string will be saved to launch_string.txt file")
              SetGadgetState(saveLaunchStringGadget, ReadPreferenceInteger("SaveLaunchString", saveLaunchStringDefault))

              useCustomJavaGadget = CheckBoxGadget(#PB_Any, 5, 155, 300, 20, "Use custom Java")
              GadgetToolTip(useCustomJavaGadget, "Use custom Java instead of installed one")
              SetGadgetState(useCustomJavaGadget, ReadPreferenceInteger("UseCustomJava", useCustomJavaDefault))

              CheckBoxGadget(313, 5, 175, 300, 20, "Use custom launch parameters")
              useCustomParamsGadget = 313
              GadgetToolTip(useCustomParamsGadget, "Use custom parameters to launch Minecraft")
              SetGadgetState(useCustomParamsGadget, ReadPreferenceInteger("UseCustomParameters", useCustomParamsDefault))

              CheckBoxGadget(689, 5, 195, 300, 20, "Keep the launcher open")
              keepLauncherOpenGadget = 689
              GadgetToolTip(keepLauncherOpenGadget, "Keep the launcher open after launching the game")
              SetGadgetState(keepLauncherOpenGadget, ReadPreferenceInteger("KeepLauncherOpen", keepLauncherOpenDefault))

              saveSettingsButton = ButtonGadget(#PB_Any, 5, 220, 325, 30, "Save and apply")

              DisableGadget(downloadThreadsGadget, Bool(Not GetGadgetState(asyncDownloadGadget)))
              DisableGadget(javaPathGadget, Bool(Not GetGadgetState(useCustomJavaGadget)))
              DisableGadget(argsGadget, Bool(Not GetGadgetState(useCustomParamsGadget)))
          EndIf
        Case useCustomParamsGadget
          DisableGadget(argsGadget, Bool(Not GetGadgetState(useCustomParamsGadget)))
        Case useCustomJavaGadget
          DisableGadget(javaPathGadget, Bool(Not GetGadgetState(useCustomJavaGadget)))
        Case asyncDownloadGadget
          If GetGadgetState(asyncDownloadGadget)
            MessageRequester("Warning", "This option is experimental and may cause crashes." + #CRLF$ + #CRLF$ + "You have been warned!")
          EndIf

          DisableGadget(downloadThreadsGadget, Bool(Not GetGadgetState(asyncDownloadGadget)))
        Case saveSettingsButton
          If GetGadgetText(downloadThreadsGadget) = "0" : SetGadgetText(downloadThreadsGadget, "5") : EndIf

          WritePreferenceInteger("DownloadMissingLibs", GetGadgetState(downloadMissingLibrariesGadget))
          WritePreferenceInteger("AsyncDownload", GetGadgetState(asyncDownloadGadget))
          WritePreferenceInteger("SaveLaunchString", GetGadgetState(saveLaunchStringGadget))
          WritePreferenceInteger("UseCustomJava", GetGadgetState(useCustomJavaGadget))
          WritePreferenceInteger("UseCustomParameters", GetGadgetState(useCustomParamsGadget))
          WritePreferenceInteger("KeepLauncherOpen", GetGadgetState(keepLauncherOpenGadget))

          If GetGadgetState(useCustomJavaGadget)
            WritePreferenceString("JavaPath", GetGadgetText(javaPathGadget))
          EndIf

          If GetGadgetState(asyncDownloadGadget)
            WritePreferenceString("DownloadThreads", GetGadgetText(downloadThreadsGadget))
          EndIf

          If GetGadgetState(useCustomParamsGadget)
            WritePreferenceString("LaunchArguments", GetGadgetText(argsGadget))
          EndIf

          findJava()

          downloadThreadsAmount = Val(GetGadgetText(downloadThreadsGadget))
          asyncDownload = GetGadgetState(asyncDownloadGadget)
        Case downloadOkButton
          CloseWindow(progressWindow)

          If IsGadget(playButton) : DisableGadget(playButton, 0) : EndIf
          If IsGadget(downloadVersionButton) : DisableGadget(downloadVersionButton, 0) : EndIf
      EndSelect
    EndIf

    If Event = #PB_Event_CloseWindow
      If EventWindow() = 1
        WritePreferenceInteger("ShowAllVersions", GetGadgetState(versionsTypeGadget))
        WritePreferenceInteger("RedownloadFiles", GetGadgetState(downloadAllFilesGadget))

        CloseWindow(1)

        DisableGadget(downloadButton, 0)
      ElseIf EventWindow() = progressWindow
        If Not IsThread(downloadThread)
          CloseWindow(progressWindow)

          If IsGadget(playButton) : DisableGadget(playButton, 0) : EndIf
          If IsGadget(downloadVersionButton) : DisableGadget(downloadVersionButton, 0) : EndIf
        Else
          MessageRequester("Download in progress", "Wait for download to complete!")
        EndIf
      ElseIf EventWindow() = 3
        CloseWindow(3)

        DisableGadget(settingsButton, 0)
      EndIf
    EndIf

  Until Event = #PB_Event_CloseWindow And EventWindow() = 0

  DeleteFile(tempDirectory + "vlauncher_download_list.txt")
EndIf
