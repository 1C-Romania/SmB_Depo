
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	FillPropertyValues(Object, Parameters);
	RefreshStatusOfControls(ThisObject);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FieldBackupDirStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
	Dialog.Directory = Object.InfobaseBackupDirectoryName;
	Dialog.CheckFileExist = True;
	Dialog.Title = NStr("en = 'Choice of the IB backup copy directory'");
	If Dialog.Choose() Then
		Object.InfobaseBackupDirectoryName = Dialog.Directory;
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateBackupOnChange(Item)
	RefreshStatusOfControls(ThisObject);
EndProcedure

&AtClient
Procedure RestoreInfobaseOnChange(Item)
	RefreshLabelOfManualRollback(ThisObject);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandOK(Command)
	Cancel = False;
	If Object.CreateBackup = 2 Then
		File	= New File(Object.InfobaseBackupDirectoryName);
		Cancel	= Not File.Exist() OR Not File.IsDirectory();
		If Cancel Then
			ShowMessageBox(, NStr("en = 'Specify existing directory for saving IB backup file.'"));
			CurrentItem = Items.FieldBackupDirectory;
		EndIf; 
	EndIf;
	If Not Cancel Then
		ChoiceResult = New Structure;
		ChoiceResult.Insert("CreateBackup",           Object.CreateBackup);
		ChoiceResult.Insert("InfobaseBackupDirectoryName",       Object.InfobaseBackupDirectoryName);
		ChoiceResult.Insert("RestoreInfobase", Object.RestoreInfobase);
		NotifyChoice(ChoiceResult);
	EndIf;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClientAtServerNoContext
Procedure RefreshStatusOfControls(Form)
	
	Form.Items.FieldBackupDirectory.AutoMarkIncomplete = (Form.Object.CreateBackup = 2);
	Form.Items.FieldBackupDirectory.Enabled = (Form.Object.CreateBackup = 2);
	InfoPages = Form.Items.PanelInformation.ChildItems;
	CreateBackup = Form.Object.CreateBackup;
	PanelInformation = Form.Items.PanelInformation;
	If CreateBackup = 0 Then // do not create
		Form.Object.RestoreInfobase = False;
		PanelInformation.CurrentPage = InfoPages.NoRollback;
	ElsIf CreateBackup = 1 Then // create temporary
		PanelInformation.CurrentPage = InfoPages.ManualRollback;
		RefreshLabelOfManualRollback(Form);
	ElsIf CreateBackup = 2 Then // Create in specified directory.
		Form.Object.RestoreInfobase = True;
		PanelInformation.CurrentPage = InfoPages.AutomaticRollback;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshLabelOfManualRollback(Form)
	PagesInscriptions = Form.Items.ManualRollbackLabelPages.ChildItems;
	Form.Items.ManualRollbackLabelPages.CurrentPage = ?(Form.Object.RestoreInfobase,
		PagesInscriptions.Restore, PagesInscriptions.DontRestore);
EndProcedure

#EndRegion
