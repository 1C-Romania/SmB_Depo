
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.Property("Parent") Then
		Object.Parent = Parameters.Parent;
	EndIf;
	
	UpdateCommandAvailabilityByRightSetting();
	
	WorkingDirectory = FileOperationsServiceServerCall.FolderWorkingDirectory(Object.Ref);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.Properties
	
	RefreshFullPath();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
	If EventName = "Write_ObjectRightsSettings" Then
		UpdateCommandAvailabilityByRightSetting();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	WorkingDirectory = FileOperationsServiceServerCall.FolderWorkingDirectory(Object.Ref);
	
	UpdateCommandAvailabilityByRightSetting();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ParentOnChange(Item)
	
	RefreshFullPath();
	
EndProcedure

&AtClient
Procedure OwnerWorkingDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		FileFunctionsServiceClient.ShowWarningAboutNeedToFileOperationsExpansion(Undefined);
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		If Write() = False Then
			Return;
		EndIf;
	EndIf;
	
	ClearMessages();
	
	Directory = "";
	Mode = FileDialogMode.ChooseDirectory;
	
	FileOpeningDialog = New FileDialog(Mode);
	FileOpeningDialog.Directory = WorkingDirectory;
	FileOpeningDialog.FullFileName = "";
	Filter = NStr("en = 'All files(*.*)|*.*'");
	FileOpeningDialog.Filter = Filter;
	FileOpeningDialog.Multiselect = False;
	FileOpeningDialog.Title = NStr("en = 'Select the folder'");
	If FileOpeningDialog.Choose() Then
		
		DirectoryName = FileOpeningDialog.Directory;
		DirectoryName = CommonUseClientServer.AddFinalPathSeparator(DirectoryName);
		
		// Create the file directory
		Try
			CreateDirectory(DirectoryName);
			TestDirectoryName = DirectoryName + "CheckAccess\";
			CreateDirectory(TestDirectoryName);
			DeleteFiles(TestDirectoryName);
		Except
			// You are not authorized to create a directory or such path is absent.
			
			ErrorText 
				= StringFunctionsClientServer.PlaceParametersIntoString(NStr("en = 'Incorrect path or no access to directory ""%1""'"),
				DirectoryName);
			
			CommonUseClientServer.MessageToUser(ErrorText, , "WorkingDirectory");
			Return;
		EndTry;
		
		WorkingDirectory = DirectoryName;
		FileOperationsServiceServerCall.SaveFolderWorkingDirectory(Object.Ref, WorkingDirectory);
		
	EndIf;
	
	RefreshDataRepresentation();
	
EndProcedure

&AtClient
Procedure OwnerWorkingDirectoryClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ParentRef = Object.Parent;
	ParentWorkingDirectory = FileOperationsServiceServerCall.FolderWorkingDirectory(ParentRef);
	FolderWorkingDirectory    = FileOperationsServiceServerCall.FolderWorkingDirectory(Object.Ref);
	
	FolderWorkingDirectoryInherited = ParentWorkingDirectory
		+ Object.Description + CommonUseClientServer.PathSeparator();
	
	If IsBlankString(ParentWorkingDirectory) Then
		
		WorkingDirectory = ""; // New working folder directory.
		FileOperationsServiceServerCall.ClearWorkingDirectory(Object.Ref);
		
	ElsIf FolderWorkingDirectoryInherited <> FolderWorkingDirectory Then
		
		WorkingDirectory = FolderWorkingDirectoryInherited; // New working folder directory.
		FileOperationsServiceServerCall.SaveFolderWorkingDirectory(Object.Ref, WorkingDirectory);
	EndIf;
	
	RefreshDataRepresentation();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OpenListOfFoldersAndFiles(Command)
	
	FormParameters = New Structure("Folder", Object.Ref);
	OpenForm("Catalog.Files.Form.Files", FormParameters, ,Object.Ref);
	
EndProcedure

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_EditContentOfProperties()
	
	PropertiesManagementClient.EditContentOfProperties(ThisObject, Object.Ref);
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure RefreshFullPath()
	
	FolderParent = CommonUse.ObjectAttributeValue(Object.Ref, "Parent");
	
	If ValueIsFilled(FolderParent) Then
	
		FullPath = "";
		While ValueIsFilled(FolderParent) Do
			
			FullPath = String(FolderParent) + "\" + FullPath;
			FolderParent = CommonUse.ObjectAttributeValue(FolderParent, "Parent");
			If Not ValueIsFilled(FolderParent) Then
				Break;
			EndIf;
			
		EndDo;
		
		FullPath = FullPath + String(Object.Ref);
		
		If Not IsBlankString(FullPath) Then
			FullPath = """" + FullPath + """";
		EndIf;
	
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateCommandAvailabilityByRightSetting()
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AccessManagement")
	 OR Items.Find("CommonCommandFormSetRights") = Undefined Then
		Return;
	EndIf;
	
	AccessControlModule = CommonUse.CommonModule("AccessManagement");
	
	If ValueIsFilled(Object.Ref)
	   AND Not AccessControlModule.IsRight("FoldersUpdate", Object.Ref) Then
		
		ReadOnly = True;
	EndIf;
	
	RightsManagement = ValueIsFilled(Object.Ref)
		AND AccessControlModule.IsRight("RightsManagement", Object.Ref);
		
	If Items.CommonCommandFormSetRights.Visible <> RightsManagement Then
		Items.CommonCommandFormSetRights.Visible = RightsManagement;
	EndIf;
	
EndProcedure

// StandardSubsystems.Properties

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisObject);
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
