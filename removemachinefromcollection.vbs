'Variable declaration
Option Explicit
Dim providerAccount  : providerAccount = ""
Dim providerPassword : providerPassword = ""
Dim providerName     : providerName = ""
Dim provSiteCode     : provSiteCode = ""   
Dim scriptmode       : scriptmode = "REMOVE"   
Dim collectionID  : collectionID = ""  'this is input 2
Dim logFileSystemObject : logFileSystemObject = Null					
Dim issmsSiteNamespaceSet : issmsSiteNamespaceSet = False
Dim smsSiteNamespace : smsSiteNamespace = Null
Dim machineResourceID: machineResourceID = 0
Dim returnVal        : returnVal = ""
Dim resourceID  : resourceID = "" 'this is input 1
Dim Failcode         : Failcode = 0
Dim DemoVersion : DemoVersion = "False"

'main processing
CreateLogFile
InitializeLogFile

resourceID = WScript.Arguments(0)
collectionID = WScript.Arguments(1)

Log ("Provided computer name:  " & resourceID )
Log ("Provided collection id:  " & collectionID )

If Failcode = 0 then
	'connect to the primary site server
	Log ("--------------------------------------------------------")
	returnVal = ""
	returnVal = SetConfigMgrNamespaceObjects(provSiteCode, providerName, providerAccount, providerPassword)
	If returnVal = False Then
		Failcode = -1
	End If
End If

If scriptmode = "REMOVE" Then
	If Failcode = 0 then
		'add new system to New Systems collection
		Log ("--------------------------------------------------------")
		returnVal = ""
		returnVal = RemoveMachineToCollection(resourceID, collectionID, smsSiteNamespace )
		If returnVal = False Then
			Failcode = -2
		End If
	End If

End If

'return failcode & resource ID for later use
Log ("--------------------------------------------------------")
Log ("Exit code = " & Failcode)
Log ("Machine ResourceID = " & ResourceID)
Log ("--------------------------------------------------------")
Log ("++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
cleanup

Function RemoveMachineToCollection(resourceID, collectionID, smsSiteNamespace )
' Import the machine into Configuration Manager.
    On Error Resume Next
    
    ' Get the collection with the given collection ID.
    Dim collection
    Set collection = smsSiteNamespace.Get ("SMS_Collection.CollectionID='" & collectionID & "'")
    If Err.number <> 0 Then
        Log ("Failed to find collection " & collectionID & ". (" & Err.number & ")")
        Log ("Error Description:  " & Err.Description)
        AddMachineToCollection = Err.number
        LogExtendedError ()
        Exit Function
    End If
    
    ' Get the machine with the given resource ID.
    Dim machineRecord
    Set machineRecord = smsSiteNamespace.Get ("SMS_R_System.ResourceId='" & resourceID & "'")
    If Err.number <> 0 Then
        Log ("Failed to find machine with Resource ID " & resourceID & ". (" & Err.number & ")")
        Log ("Error Description:  " & Err.Description)
        AddMachineToCollection = Err.number
        LogExtendedError ()
        Exit Function
    End If
    
    ' Get the machine name and convert resourceID to a long int to be used in further queries.
    Dim machineName
    machineName = machineRecord.Properties_.item("Name")
    resourceID = CLng (resourceID)
      
    ' Setup the collection rule.
    Dim collectionRule 
    Set collectionRule = smsSiteNamespace.Get ("SMS_CollectionRuleDirect").SpawnInstance_()
    If Err.number <> 0 Then
        Log ("Failed to create a SMS_CollectionRuleDirect instance. (" & Err.number & ")")
        Log ("Error Description:  " & Err.Description)
        AddMachineToCollection = Err.number
        LogExtendedError ()
        Exit Function
    End If
    ' Set the collection rule properties.
    ' Setting the collection rule based on the system properties, hence ResourceClassName = "SMS_R_System".
    collectionRule.ResourceClassName = "SMS_R_System"
    ' Give the rule a name. Using the machine name itself here.
    collectionRule.RuleName = machineName
    ' Set the ResourceID to the resource ID of the machine.
    collectionRule.ResourceID = resourceID
   
    ' Execute the DeleteMembershipRule method to add the machine to the collection.
    Dim inParam, outParams
    Set inParam = collection.Methods_("DeleteMembershipRule").inParameters.SpawnInstance_()
    ' Set the input parameters.
    inParam.Properties_.item("collectionRule") = collectionRule
    ' Execute the DeleteMembershipRule method.
    Set outParams = collection.ExecMethod_("DeleteMembershipRule", inParam) 
    If Err.number <> 0 Then
        Log ("Failed to remove " & machineName & "from the Collection " & collectionID & ". (" & Err.number & ")")
        Log ("Error Description:  " & Err.Description)
        RemoveMachineToCollection = Err.number
        LogExtendedError ()
        Exit Function
    End If
    On Error Goto 0
      
    ' Return success.
    Log ("Successfully removed '" & machineName & "' from collection " & collectionID & ".")
    RemoveMachineToCollection = True
End Function

Function CreateLogFile()
' Create/Open the log file.
   
    ' Form the complete file path to save the log.
    Dim fileSystem, completeLogFilePath
    Set fileSystem = CreateObject ("Scripting.FileSystemObject")
'    completeLogFilePath = fileSystem.GetAbsolutePathName (".") & "\HTAApplication.log"
    completeLogFilePath = fileSystem.GetSpecialFolder (2) & "\GlobalSOEGUI.log"

    ' Create the file and write the log to it.
    ' ForAppending = 8
    Set logFileSystemObject = fileSystem.OpenTextFile (completeLogFilePath, 8, True)
    
    ' Set the return value to the log file path
    CreateLogFile = completeLogFilePath
End Function

Sub cleanup
    'Delete values so they don't get saved to variables.dat
    providerAccount = ""
    providerPassword = ""
End Sub

Function InitializeLogFile
	Log ("++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
	Log ("Provider Account:  " & providerAccount)
	InitializeLogFile = True
End Function

Function Log(logEntry)
    ' Prepend current time to the input log entry.
    Dim lineOfLog, consolidatedLog
    lineOfLog = Now & " - " & logEntry 
    ' If the log file is not created or opened, do it now.
    If (IsNull (logFileSystemObject) = True) Then
        Dim logFileName
        logFileName = CreateLogFile ()
    End If
    ' If the log file is created, add the log to the end of the log file.
    ' The log in the log file is always chronological, i.e. the latest log at the end of the file.
    If (IsNull (logFileSystemObject) = False) Then
        logFileSystemObject.WriteLine (lineOfLog)
    End If
    Log = consolidatedLog
End Function

Function LogExtendedError
' This function logs the additional error information from the WMI and SMS error objects.
    On Error Resume Next
    Dim extendedStatus
    Set extendedStatus = CreateObject ("WbemScripting.SWBEMLastError")
    ' Determine the type of error.
    If extendedStatus.Path_.Class = "__ExtendedStatus" Then
        Log ("WMI Error: " & extendedStatus.Description)
    ElseIf extendedStatus.Path_.Class = "SMS_ExtendedStatus" Then
        Log ("SMS Provider Error")
        Log ("Description: " & extendedStatus.Description)
        Log ("Error Code:  " & extendedStatus.ErrorCode)
    End If
    On Error Goto 0
End Function

Function SetConfigMgrNamespaceObjects(siteCode, providerName, providerAccount, providerPassword)
' Create and set Configuration Manager provider objects.
    Dim locator
    ' Check if the smsSiteNamespace is not previously set.
    If issmsSiteNamespaceSet = False Then
        ' Connect to the SMS\Site_<Sitecode> namespace on the provider machine.
        Set locator = CreateObject ("WbemScripting.SWbemLocator")
        On Error Resume Next
        Set smsSiteNamespace = locator.ConnectServer (providerName, "root\sms\site_" & siteCode, _
                                                    providerAccount, providerPassword )
        If Err.number <> 0 Then
            Log ("Failed to connect to SMS provider. (" & Err.number & ")")
            Log ("Error Description:  " & Err.Description)
            LogExtendedError ()
            Exit Function
        End If
        On Error Goto 0
        
        ' Setting ImpersonationLevel = impersonate and AuthenticationLevel = PktPrivacy.
        smsSiteNamespace.Security_.ImpersonationLevel = 3
        smsSiteNamespace.Security_.AuthenticationLevel = 6
        Log ("Successfully connected to the SMS Provider on: " & providerName &_
            " and set the Configuration Manager Namespace objects " & Err.number)
        issmsSiteNamespaceSet = True
        SetConfigMgrNamespaceObjects = True
    Else
        Log ("Configuration Manager Namespace object variables are already set")
    End If
End Function
