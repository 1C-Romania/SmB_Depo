&AtClient
Var CurrentRecordParameters;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		Object.FillOrder = FindMaximumOrder() + 1;
	Else
		Items.FullPathLinux.WarningOnEditRepresentation
			= WarningOnEditRepresentation.Show;
		
		Items.FullPathWindows.WarningOnEditRepresentation
			= WarningOnEditRepresentation.Show;
		
		CurrentSizeInBytes = 0;
		
		FileFunctionsService.OnDefenitionSizeOfFilesOnVolume(
			Object.Ref, CurrentSizeInBytes);
			
		CurrentSize = CurrentSizeInBytes / (1024 * 1024);
		If CurrentSize = 0 AND CurrentSizeInBytes <> 0 Then
			CurrentSize = 1;
		EndIf;
	EndIf;
	
	ServerPlatformType = CommonUseReUse.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86
	 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		Items.FullPathWindows.AutoMarkIncomplete = True;
	Else
		Items.FullPathLinux.AutoMarkIncomplete = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseNotification", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not WriteParameters.Property("ExternalResourcesAllowed") Then
		Cancel = True;
		CurrentRecordParameters = WriteParameters;
		AttachIdleHandler("AllowExternalResourceBegin", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If ValueIsFilled(RefNew) Then
		CurrentObject.SetNewObjectRef(RefNew);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	CurrentObject = FormAttributeToValue("Object");
	
	If CheckFillingIsAlreadyPerformed Then
		CheckFillingIsAlreadyPerformed = False;
		CurrentObject.AdditionalProperties.Insert("SkipMainFillingCheck");
	Else
		CurrentObject.AdditionalProperties.Insert("SkipAccessCheckToFolder");
	EndIf;
	
	CheckedAttributes.Clear();
	
	If Not CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FullPathWindowsOnChange(Item)
	
	// Add a slash at the end in case it is absent.
	If Not IsBlankString(Object.FullPathWindows) Then
		If Right(Object.FullPathWindows, 1) <> "\" Then
			Object.FullPathWindows = Object.FullPathWindows + "\";
		EndIf;
		
		If Right(Object.FullPathWindows, 2) = "\\" Then
			Object.FullPathWindows = Left(Object.FullPathWindows, StrLen(Object.FullPathWindows) - 1);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure FullPathLinuxOnChange(Item)
	
	// Add a slash at the end in case it is absent.
	If Not IsBlankString(Object.FullPathLinux) Then
		If Right(Object.FullPathLinux, 1) <> "\" Then
			Object.FullPathLinux = Object.FullPathLinux + "\";
		EndIf;
		
		If Right(Object.FullPathLinux, 2) = "\\" Then
			Object.FullPathLinux = Left(Object.FullPathLinux, StrLen(Object.FullPathLinux) - 1);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure WriteAndCloseNotification(Result = Undefined, NotSpecified = Undefined) Export
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

// Finds the maximum order among the volumes.
&AtServer
Function FindMaximumOrder()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MAX(volume.FillOrder) AS MaximumNumber
	|FROM
	|	Catalog.FileStorageVolumes AS volume";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		If Selection.MaximumNumber = Null Then
			Return 0;
		Else
			Return Number(Selection.MaximumNumber);
		EndIf;
	EndIf;
	
	Return 0;
	
EndFunction

&AtClient
Procedure AllowExternalResourceBegin()
	
	ExternalResourceQueries = New Array;
	If Not CheckFillingAtServer(ExternalResourceQueries) Then
		Return;
	EndIf;
	
	ClosingAlert = New NotifyDescription(
		"AllowExternalResourceEnd", ThisObject, CurrentRecordParameters);
	
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(
		ExternalResourceQueries, ThisObject, ClosingAlert);
	
EndProcedure

&AtServer
Function CheckFillingAtServer(ExternalResourceQueries)
	
	If Not CheckFilling() Then
		Return False;
	EndIf;
	
	CheckFillingIsAlreadyPerformed = True;
	
	If ValueIsFilled(Object.Ref) Then
		ObjectReference = Object.Ref;
	Else
		If Not ValueIsFilled(RefNew) Then
			RefNew = Catalogs.FileStorageVolumes.GetRef();
		EndIf;
		ObjectReference = RefNew;
	EndIf;
	
	ExternalResourceQueries.Add(
		Catalogs.FileStorageVolumes.QueryOnExternalResourcesUseForVolume(
			ObjectReference, Object.FullPathWindows, Object.FullPathLinux));
	
	Return True;
	
EndFunction

&AtClient
Procedure AllowExternalResourceEnd(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		WriteParameters.Insert("ExternalResourcesAllowed");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

#EndRegion
