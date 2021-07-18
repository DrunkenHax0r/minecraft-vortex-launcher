
Procedure showLaunchErrors(PID)
  
  Protected.s javaErrorDescription, javaErrorString
  
  If PID
    WaitProgram(PID,1000);
    If Not ProgramRunning(PID)
      javaErrorString = "initial"
      While StringByteLength(javaErrorString)
        javaErrorString  = ReadProgramError(PID)
        javaErrorDescription = javaErrorDescription + javaErrorString + #CRLF$ + #CRLF$ 
      Wend
    EndIf
  EndIf
  
  If Not StringByteLength(javaErrorDescription) = 0 
    MessageRequester("Error", "Java error: "+ #CRLF$ + #CRLF$ +javaErrorDescription)
  EndIf
  
EndProcedure

Procedure initPathSeperator(osPS)
  
  Select OSVersion()
    Case   #PB_OS_Linux_2_2 Or #PB_OS_Linux_2_4 Or #PB_OS_Linux_2_6 Or #PB_OS_Linux_Future
      osPS = #NPS$
    Default
      osPS = #PS$
  EndSelect
  
  Return 
  
EndProcedure

Procedure generateProfileJson()
  Protected.s fileName = "launcher_profiles.json"
  Protected.i file
  Protected.i lastProfilesJsonSize = ReadPreferenceInteger("LastProfilesJsonSize", 89)
  Protected.i fileSize = FileSize(fileName)

  If fileSize <= 0
    DeleteFile(fileName)
    file = OpenFile(#PB_Any, fileName)

    If file
      WriteString(file, "{ " + Chr(34) + "profiles" + Chr(34) + ": { " + Chr(34) + "justProfile" + Chr(34) + ": { " + Chr(34) + "name" + Chr(34) + ": " + Chr(34) + "justProfile" + Chr(34) + ", ")
      WriteString(file, Chr(34) + "lastVersionId" + Chr(34) + ": " + Chr(34) + "1.12.2" + Chr(34) + " } } }" + #CRLF$)

      CloseFile(file)
    EndIf
  EndIf

  fileSize = FileSize(fileName)

  If fileSize <> lastProfilesJsonSize
    forceDownloadMissingLibraries = 1
  EndIf

  WritePreferenceInteger("LastProfilesJsonSize", fileSize)
EndProcedure

Procedure findInstalledVersions()
  Protected.s dirName, chosenVer = ReadPreferenceString("ChosenVer", "")
  Protected.i directory, chosenFound

  directory = ExamineDirectory(#PB_Any, "versions", "*")

  DisableGadget(playButton, 0)
  DisableGadget(versionsGadget, 0)
  DisableGadget(deleteVersionButton, 0)

  If directory
    While NextDirectoryEntry(directory)
      If DirectoryEntryType(directory) = #PB_DirectoryEntry_Directory
        dirName = DirectoryEntryName(directory)

        If dirName <> ".." And dirName <> "."
          If FileSize("versions\" + dirName + "\" + dirName + ".json") > -1
            If Not chosenFound And dirName = chosenVer
              chosenFound = 1
            EndIf

            AddGadgetItem(versionsGadget, -1, dirName)
          EndIf
        EndIf
      EndIf
    Wend

    FinishDirectory(directory)

    If chosenFound
      SetGadgetText(versionsGadget, chosenVer)
    Else
      SetGadgetState(versionsGadget, 0)
    EndIf
  EndIf

  If Not CountGadgetItems(versionsGadget)
    DisableGadget(playButton, 1)
    DisableGadget(versionsGadget, 1) : AddGadgetItem(versionsGadget, 0, "Versions not found") : SetGadgetState(versionsGadget, 0)
    DisableGadget(deleteVersionButton, 1)
  Else
    generateProfileJson()
  EndIf
EndProcedure

Procedure.s parseVersionsManifest(versionType.i = 0, getClientJarUrl.i = 0, clientVersion.s = "")
  Protected.i jsonFile, jsonObject, jsonVersionsArray, jsonArrayElement, i
  Protected.s url

  jsonFile = ParseJSON(#PB_Any, versionsManifestString)

  If jsonFile
    jsonObject = JSONValue(jsonFile)

    jsonVersionsArray = GetJSONMember(jsonObject, "versions")

    For i = 0 To JSONArraySize(jsonVersionsArray) - 1
      jsonArrayElement = GetJSONElement(jsonVersionsArray, i)

      If getClientJarUrl = 0 And versionType = 0 And GetJSONString(GetJSONMember(jsonArrayElement, "type")) <> "release"
        Continue
      EndIf

      If getClientJarUrl = 0
        AddGadgetItem(versionsDownloadGadget, -1, GetJSONString(GetJSONMember(jsonArrayElement, "id")))
      Else
        If GetJSONString(GetJSONMember(jsonArrayElement, "id")) = clientVersion
          url = GetJSONString(GetJSONMember(jsonArrayElement, "url"))
          FreeJSON(jsonFile)

          ProcedureReturn url
        EndIf
       EndIf
    Next

    FreeJSON(jsonFile)
  Else
    AddGadgetItem(versionsDownloadGadget, -1, "Error")
    DisableGadget(downloadVersionButton, 1)
  EndIf

  SetGadgetState(versionsDownloadGadget, 0)
EndProcedure

Procedure.s parseLibraries(clientVersion.s, prepareForDownload.i = 0)
  Protected.i jsonLibrariesArray, jsonArrayElement, jsonFile, fileSize, downloadListFile, zipFile
  Protected.i jsonArtifactsMember, jsonDownloadsMember, jsonUrlMember, jsonClassifiersMember, jsonNativesLinuxMember
  Protected.i jsonRulesMember, jsonRulesOsMember
  Protected.i i, k
  Protected.i allowLib

  Protected.s libName, libsString, packFileName, url
  Protected.s jsonRulesOsName
  Protected Dim libSplit.s(3)

  If prepareForDownload = 1
    downloadListFile = OpenFile(#PB_Any, tempDirectory + "vlauncher_download_list.txt")
    FileSeek(downloadListFile, Lof(downloadListFile), #PB_Relative)
  EndIf

  UseZipPacker()

  jsonFile = ParseJSON(#PB_Any, fileRead("versions\" + clientVersion + "\" + clientVersion + ".json"))

  If jsonFile
    jsonLibrariesArray = GetJSONMember(JSONValue(jsonFile), "libraries")

    For i = 0 To JSONArraySize(jsonLibrariesArray) - 1
      jsonArrayElement = GetJSONElement(jsonLibrariesArray, i)
      allowLib = 1
      jsonRulesOsName = "empty"

      jsonRulesMember = GetJSONMember(jsonArrayElement, "rules")

      If jsonRulesMember
        For k = 0 To JSONArraySize(jsonRulesMember) - 1
          jsonRulesOsMember = GetJSONMember(GetJSONElement(jsonRulesMember, k), "os")

          If jsonRulesOsMember
            jsonRulesOsName = GetJSONString(GetJSONMember(jsonRulesOsMember, "name"))
          EndIf

          If GetJSONString(GetJSONMember(GetJSONElement(jsonRulesMember, k), "action")) = "allow"
            If jsonRulesOsName <> "empty" And jsonRulesOsName <> "windows"
              allowLib = 0
            EndIf
          Else
            If jsonRulesOsName = "windows"
              allowLib = 0
            EndIf
          EndIf
        Next
      EndIf

      If allowLib
        libName = GetJSONString(GetJSONMember(jsonArrayElement, "name"))

        For k = 1 To 3
          libSplit(k) = StringField(libName, k, ":")
        Next

        libName = ReplaceString(libSplit(1), ".", "\") + "\" + libSplit(2) + "\" + libSplit(3) + "\" + libSplit(2) + "-" + libSplit(3)

        If prepareForDownload = 1
          jsonDownloadsMember = GetJSONMember(jsonArrayElement, "downloads")

          If jsonDownloadsMember
            jsonArtifactsMember = GetJSONMember(jsonDownloadsMember, "artifact")
            jsonClassifiersMember = GetJSONMember(jsonDownloadsMember, "classifiers")

            If jsonClassifiersMember
              jsonNativesLinuxMember = GetJSONMember(jsonClassifiersMember, "natives-windows")

              If jsonNativesLinuxMember
                url = GetJSONString(GetJSONMember(jsonNativesLinuxMember, "url"))
                fileSize = GetJSONInteger(GetJSONMember(jsonNativesLinuxMember, "size"))

                libName + "-natives-windows"
              EndIf
            ElseIf jsonArtifactsMember
              url = GetJSONString(GetJSONMember(jsonArtifactsMember, "url"))
              fileSize = GetJSONInteger(GetJSONMember(jsonArtifactsMember, "size"))
            EndIf
          Else
            jsonUrlMember = GetJSONMember(jsonArrayElement, "url")

            If jsonUrlMember
              url = GetJSONString(jsonUrlMember) + ReplaceString(libName, "\", "/") + ".jar"
            Else
              url = "https://libraries.minecraft.net/" + ReplaceString(libName, "\", "/") + ".jar"
            EndIf
          EndIf

          WriteStringN(downloadListFile, url + "::" + "libraries\" + libName + ".jar" + "::" + fileSize)
        EndIf

        If Not GetJSONMember(jsonArrayElement, "natives")
          libsString + "libraries\" + libName + ".jar;"
        Else
          If Not Right(libName, 15) = "natives-windows"
            zipFile = OpenPack(#PB_Any, "libraries\" + libName + "-natives-windows.jar")
          Else
            zipFile = OpenPack(#PB_Any, "libraries\" + libName + ".jar")
          EndIf

          If zipFile
            CreateDirectoryRecursive("versions\" + clientVersion + "\natives")

            If ExaminePack(zipFile)
              While NextPackEntry(zipFile)
                If PackEntryType(zipFile) = #PB_Packer_File
                  packFileName = PackEntryName(zipFile)

                  If FileSize("versions\" + clientVersion + "\natives\" + packFileName) < 1
                    UncompressPackFile(zipFile, "versions\" + clientVersion + "\natives\" + packFileName)
                  EndIf
                EndIf
              Wend
            EndIf

            ClosePack(zipFile)
          EndIf
        EndIf
      EndIf
    Next
  EndIf

  FreeJSON(jsonFile)
  FreeArray(libSplit())

  If prepareForDownload = 1 : CloseFile(downloadListFile) : EndIf

  ProcedureReturn libsString
EndProcedure

Procedure downloadFiles(downloadAllFiles.i)
  Protected Dim httpArray.i(downloadThreadsAmount)
  Protected Dim strings.s(downloadThreadsAmount)
  Protected Dim retries.i(downloadThreadsAmount)

  Protected.i failedDownloads, succeededDownloads, linesTotal, lines, allowedRetries = 5
  Protected.s string
  Protected.i file, fileSize, requiredSize, i
  Protected.i currentDownloads
  Protected.i retries

  file = ReadFile(#PB_Any, tempDirectory + "vlauncher_download_list.txt")

  If file
    While Eof(file) = 0
      ReadString(file)
      lines + 1
    Wend

    linesTotal = lines

    FileSeek(file, 0)

    If IsGadget(downloadVersionButton) : DisableGadget(downloadVersionButton, 1) : EndIf
    If IsGadget(progressBar) : SetGadgetAttribute(progressBar, #PB_ProgressBar_Maximum, linesTotal) : EndIf

    InitNetwork()

    If asyncDownload
      While (Eof(file) = 0 Or currentDownloads > 0) And failedDownloads <= 5
        For i = 0 To downloadThreadsAmount
          If httpArray(i) = 0
            string = ReadString(file)

            If string
              fileSize = FileSize(StringField(string, 2, "::"))
              requiredSize = Val(StringField(string, 3, "::"))

              If (downloadAllFiles = 0 And (fileSize = -1 Or (requiredSize <> 0 And fileSize <> requiredSize))) Or downloadAllFiles = 1
                CreateDirectoryRecursive(GetPathPart(StringField(string, 2, "::")))

                httpArray(i) = ReceiveHTTPFile(StringField(string, 1, "::"), StringField(string, 2, "::"), #PB_HTTP_Asynchronous)
                strings(i) = string
                retries(i) = 0

                currentDownloads + 1
              Else
                lines - 1
              EndIf
            EndIf
          ElseIf HTTPProgress(httpArray(i)) = #PB_HTTP_Success
            currentDownloads - 1
            lines - 1

            FinishHTTP(httpArray(i))
            httpArray(i) = 0
          ElseIf HTTPProgress(httpArray(i)) = #PB_HTTP_Failed
            FinishHTTP(httpArray(i))

            If retries(i) < allowedRetries
              httpArray(i) = ReceiveHTTPFile(StringField(strings(i), 1, "::"), StringField(strings(i), 2, "::"), #PB_HTTP_Asynchronous)
              retries(i) + 1
            Else
              retries(i) = 0
              httpArray(i) = 0

              failedDownloads + 1
              currentDownloads - 1
            EndIf
          EndIf
        Next

        If IsGadget(progressBar) : SetGadgetState(progressBar, linesTotal - lines) : EndIf
        If IsGadget(filesLeft) : SetGadgetText(filesLeft, "Files remaining: " + lines): EndIf

        Delay(500)
      Wend
    Else
      While Eof(file) = 0
        string = ReadString(file)

        If string
          lines - 1

          fileSize = FileSize(StringField(string, 2, "::"))
          requiredSize = Val(StringField(string, 3, "::"))

          If (downloadAllFiles = 0 And (fileSize = -1 Or (requiredSize <> 0 And fileSize <> requiredSize))) Or downloadAllFiles = 1
            CreateDirectoryRecursive(GetPathPart(StringField(string, 2, "::")))

            If ReceiveHTTPFile(StringField(string, 1, "::"), StringField(string, 2, "::"))
              retries = 0
            Else
              If retries < allowedRetries
                retries + 1
                FileSeek(file, -1, #PB_Relative)

                Continue
              Else
                failedDownloads = 1

                Break
              EndIf
            EndIf
          EndIf
        EndIf

        If IsGadget(progressBar) : SetGadgetState(progressBar, linesTotal - lines) : EndIf
        If IsGadget(filesLeft) : SetGadgetText(filesLeft, "Files remaining: " + lines) : EndIf
      Wend
    EndIf

    If failedDownloads
      If IsGadget(filesLeft) : SetGadgetText(filesLeft, "Download failed! " + lines + " files left.") : EndIf
    Else
      If IsGadget(filesLeft) : SetGadgetText(filesLeft, "Download complete!") : EndIf
    EndIf

    If IsGadget(progressBar) : HideGadget(progressBar, 1) : EndIf
    If IsGadget(downloadOkButton) : HideGadget(downloadOkButton, 0) : EndIf

    ClearGadgetItems(versionsGadget)
    findInstalledVersions()

    CloseFile(file)
  EndIf

  FreeArray(httpArray())
  FreeArray(strings())
  DeleteFile(tempDirectory + "vlauncher_download_list.txt")
EndProcedure

Procedure progressWindow(clientVersion.s)
  progressWindow = OpenWindow(#PB_Any, #PB_Ignore, #PB_Ignore, 230, 85, "Download progress")

  If progressWindow
    downloadingClientTextGadget = TextGadget(#PB_Any, 5, 5, 220, 20, "Version: " + clientVersion)
    filesLeft = TextGadget(#PB_Any, 5, 25, 220, 20, "Files remaining: unknown")
    progressBar = ProgressBarGadget(#PB_Any, 5, 50, 220, 20, 0, 100, #PB_ProgressBar_Smooth)
    downloadOkButton = ButtonGadget(#PB_Any, 5, 50, 220, 30, "OK")

    HideGadget(downloadOkButton, 1)
  EndIf
EndProcedure

Procedure CreateDirectoryRecursive(path.s)
  Protected.s fullPath, pathElement
  Protected.i i = 1

  Repeat
    pathElement = StringField(path, i, "\")
    fullPath + pathElement + "\"

    CreateDirectory(fullPath)

    i + 1
  Until pathElement = ""
EndProcedure

Procedure.s fileRead(pathToFile.s)
  Protected.i file
  Protected.s fileContent

  file = ReadFile(#PB_Any, pathToFile)

  If file
    Repeat
      fileContent + ReadString(file) + #CRLF$
    Until Eof(file)

    CloseFile(file)
  EndIf

  ProcedureReturn fileContent
EndProcedure

Procedure findJava()
  Protected.s dirName, javaBinaryPath, customJavaPath
  Protected.i i, directory

  ClearGadgetItems(javaListGadget)
  DisableGadget(javaListGadget, 0)

  If GetGadgetText(versionsGadget) <> "Versions not found" And Not IsThread(downloadThread)
    DisableGadget(playButton, 0)
  EndIf

  If ReadPreferenceInteger("UseCustomJava", useCustomJavaDefault)
    AddGadgetItem(javaListGadget, -1, "Custom Java enabled in Settings")
    SetGadgetState(javaListGadget, 0)
    DisableGadget(javaListGadget, 1)
  Else
    For i = 0 To 1
      If programFilesDir(i) <> "\"
        directory = ExamineDirectory(#PB_Any, programFilesDir(i) + "Java", "*")

        If directory
          While NextDirectoryEntry(directory) And DirectoryEntryType(directory) = #PB_DirectoryEntry_Directory
            dirName = DirectoryEntryName(directory)

            If dirName <> ".." And dirName <> "." And FileSize(programFilesDir(i) + "Java\" + dirName + "\bin\javaw.exe") > 0
              If i
                dirName + " (x32)"
              EndIf

              AddGadgetItem(javaListGadget, -1, dirName)
              SetGadgetState(javaListGadget, 0)
            EndIf
          Wend

          FinishDirectory(directory)
        EndIf
      EndIf
    Next

    If Not CountGadgetItems(javaListGadget)
      AddGadgetItem(javaListGadget, -1, "Java not found")
      SetGadgetState(javaListGadget, 0)

      DisableGadget(javaListGadget, 1)
      DisableGadget(playButton, 1)
    EndIf
  EndIf
EndProcedure

Procedure assetsToResources(assetsIndex.s)
  Protected.i jsonFile, jsonObject, jsonObjectObjects, fileSize
  Protected.s fileHash, fileName

  jsonFile = ParseJSON(#PB_Any, fileRead("assets\indexes\" + assetsIndex + ".json"))

  If jsonFile
    jsonObject = JSONValue(jsonFile)
    jsonObjectObjects = GetJSONMember(jsonObject, "objects")

    If ExamineJSONMembers(jsonObjectObjects)
      While NextJSONMember(jsonObjectObjects)
        fileHash = GetJSONString(GetJSONMember(GetJSONMember(jsonObjectObjects, JSONMemberKey(jsonObjectObjects)), "hash"))
        fileSize = GetJSONInteger(GetJSONMember(GetJSONMember(jsonObjectObjects, JSONMemberKey(jsonObjectObjects)), "size"))
        fileName = JSONMemberKey(jsonObjectObjects)

        fileName = ReplaceString(fileName, "/", "\")

        If FileSize("resources\" + fileName) <> fileSize
          CreateDirectoryRecursive("resources\" + GetPathPart(fileName))

          CopyFile("assets\objects\" + Left(fileHash, 2) + "\" + fileHash, "resources\" + fileName)
        EndIf
      Wend
    EndIf

    FreeJSON(jsonFile)
  EndIf
EndProcedure

Procedure.s removeSpacesFromVersionName(clientVersion.s)
  Protected.s newVersionName = ReplaceString(clientVersion, " ", "-")

  RenameFile("versions\" + clientVersion + "\" + clientVersion + ".jar", "versions\" + clientVersion + "\" + newVersionName + ".jar")
  RenameFile("versions\" + clientVersion + "\" + clientVersion + ".json", "versions\" + clientVersion + "\" + newVersionName + ".json")
  RenameFile("versions\" + clientVersion, "versions\" + newVersionName)

  ProcedureReturn newVersionName
EndProcedure
