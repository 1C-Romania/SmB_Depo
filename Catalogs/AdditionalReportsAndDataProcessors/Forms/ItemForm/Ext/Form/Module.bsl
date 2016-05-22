&AtClient
Var ClientCache;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Check of possibility to import new data processors in infobase.
	IsNew = Object.Ref.IsEmpty();
	AddRight = AdditionalReportsAndDataProcessors.AddRight();
	If Not AddRight Then
		If IsNew Then
			Raise NStr("en = 'Insufficient access rights for adding additional reports and processors.'");
		Else
			Items.LoadFromFile.Visible = False;
			Items.ExportToFile.Visible = False;
		EndIf;
	EndIf;
	
	// Restriction of possibility to select the publication kind in dependency of infobase settings.
	Items.Publication.ChoiceList.Clear();
	PublicationsAvailableTypes = AdditionalReportsAndDataProcessorsReUse.PublicationsAvailableTypes();
	For Each PublicationType In PublicationsAvailableTypes Do
		Items.Publication.ChoiceList.Add(PublicationType);
	EndDo;
	
	// Restriction to display extended information.
	RepresentationOfExtendedInformation = AdditionalReportsAndDataProcessors.ShowExtendedInformation(Object.Ref);
	Items.PageAdditionalInformation.Visible = RepresentationOfExtendedInformation;
	
	// Restriction to import data processor from file / save to file.
	If Not AdditionalReportsAndDataProcessors.ItIsPossibleToImportProcessingsFromFile(Object.Ref) Then
		Items.LoadFromFile.Visible = False;
	EndIf;
	If Not AdditionalReportsAndDataProcessors.DataProcessorExportToFileIsAvailable(Object.Ref) Then
		Items.ExportToFile.Visible = False;
	EndIf;
	
	KindAdditionalInformationProcessor = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalInformationProcessor;
	TypeAdditionalReport     = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport;
	ReportKind                   = Enums.AdditionalReportsAndDataProcessorsKinds.Report;
	
	Parameters.Property("ShowDialogLoadFromFileOnOpen", ShowDialogLoadFromFileOnOpen);
	
	If IsNew Then
		Object.UseForObjectForm = True;
		Object.UseForListForm  = True;
		ShowDialogLoadFromFileOnOpen = True;
	EndIf;
	
	If ShowDialogLoadFromFileOnOpen AND Not Items.LoadFromFile.Visible Then
		Raise NStr("en = 'Insufficient rights for importing additional reports and data processors'");
	EndIf;
	
	FillCommands();
	
	PermissionAdress = PutToTempStorage(
		FormAttributeToValue("Object").permissions.Unload(),
		ThisObject.UUID);
	
	SetVisibleEnabled();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ClientCache = New Structure;
	
	If ShowDialogLoadFromFileOnOpen Then
		AttachIdleHandler("UpdateFromFileStart", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("Catalog.AdditionalReportsAndDataProcessors.Form.FillSections") Then
		
		If TypeOf(ValueSelected) <> Type("ValueList") Then
			Return;
		EndIf;
		
		Object.Sections.Clear();
		For Each ItemOfList In ValueSelected Do
			NewRow = Object.Sections.Add();
			NewRow.Section = ItemOfList.Value;
		EndDo;
		
		Modified = True;
		SetVisibleEnabled();
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("Catalog.AdditionalReportsAndDataProcessors.Form.QuickAccessToAdditionalReportsAndDataProcessors") Then
		
		If TypeOf(ValueSelected) <> Type("ValueList") Then
			Return;
		EndIf;
		
		ItemCommand = Object.Commands.FindByID(ClientCache.IDRowsCommands);
		If ItemCommand = Undefined Then
			Return;
		EndIf;
		
		Found = QuickAccess.FindRows(New Structure("CommandID", ItemCommand.ID));
		For Each TableRow In Found Do
			QuickAccess.Delete(TableRow);
		EndDo;
		
		For Each ItemOfList In ValueSelected Do
			TableRow = QuickAccess.Add();
			TableRow.CommandID = ItemCommand.ID;
			TableRow.User = ItemOfList.Value;
		EndDo;
		
		ItemCommand.QuickAccessView = UsersQuickAccessPresentation(ValueSelected.Count());
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "MetadataObjectsSelection" Then
		
		ImportSelectedMetadataObjects(Parameter);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If AdditionalReportsAndDataProcessors.DataProcessorExportToFileIsAvailable(Object.Ref) Then
		
		DataProcessorDataAddress = PutToTempStorage(
			CurrentObject.DataProcessorStorage.Get(),
			UUID);
		
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", CurrentObject.Ref);
	Query.Text =
	"SELECT
	|	RegistersData.CommandID,
	|	RegistersData.User
	|FROM
	|	InformationRegister.UserSettingsOfAccessToDataProcessors AS RegistersData
	|WHERE
	|	RegistersData.AdditionalReportOrDataProcessor = &Ref
	|	AND RegistersData.Available = TRUE
	|	AND Not RegistersData.User.DeletionMark
	|	AND Not RegistersData.User.NotValid";
	QuickAccess.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	If DataProcessorRegistration AND AdditionalReportsAndDataProcessors.ItIsPossibleToImportProcessingsFromFile(Object.Ref) Then
		DataProcessorBinaryData = GetFromTempStorage(DataProcessorDataAddress);
		CurrentObject.DataProcessorStorage = New ValueStorage(DataProcessorBinaryData, New Deflation(9));
	EndIf;
	
	If Object.Type = KindAdditionalInformationProcessor OR Object.Type = TypeAdditionalReport Then
		CurrentObject.AdditionalProperties.Insert("ActualCommands", Object.Commands.Unload());
	Else
		QuickAccess.Clear();
	EndIf;
	
	CurrentObject.AdditionalProperties.Insert("QuickAccess", QuickAccess.Unload());
	
	CurrentObject.permissions.Load(GetFromTempStorage(PermissionAdress));
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	If CurrentObject.AdditionalProperties.Property("ErrorConnection") Then
		MessageText = CurrentObject.AdditionalProperties.ErrorConnection;
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	IsNew = False;
	If DataProcessorRegistration Then
		RefreshReusableValues();
		DataProcessorRegistration = False;
	EndIf;
	FillCommands();
	SetVisibleEnabled();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	AdditionalReportsAndDataProcessorsClient.EditMultilineText(
		ThisObject,
		Item.EditText,
		Object,
		"Comment"
	);
EndProcedure

&AtClient
Procedure AdditionalReportVariantsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure AdditionalReportVariantsBeforeRowChange(Item, Cancel)
	Cancel = True;
	OpenOption();
EndProcedure

&AtClient
Procedure AdditionalReportVariantsBeforeDelete(Item, Cancel)
	Cancel = True;
	Variant = Items.AdditionalReportVariants.CurrentData;
	If Variant = Undefined Then
		Return;
	EndIf;
	
	If Not Variant.User Then
		ShowMessageBox(, NStr("en = 'You can not mark the predefined report variant for deletion.'"));
		Return;
	EndIf;
	
	QuestionText = NStr("en = 'Mark ""%1"" for deletion?'");
	QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(QuestionText, Variant.Description);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Variant", Variant);
	Handler = New NotifyDescription("AdditionalReportVariantsBeforeDeleteEnding", ThisObject, AdditionalParameters);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure UseForListFormOnChange(Item)
	If Not Object.UseForObjectForm AND Not Object.UseForListForm Then
		Object.UseForObjectForm = True;
	EndIf;
EndProcedure

&AtClient
Procedure UseForObjectFormOnChange(Item)
	If Not Object.UseForObjectForm AND Not Object.UseForListForm Then
		Object.UseForListForm = True;
	EndIf;
EndProcedure

&AtClient
Procedure DecorationEnablingfSecurityProfilesLabelDataProcessorNavigationRefs(Item, URL, StandardProcessing)
	
	If URL = "int://sp-on" Then
		
		OpenForm(
			"DataProcessor.PermissionSettingsForExternalResourcesUse.Form.SecurityProfilesUseSettings",
			,
			,
			,
			,
			,
			,
			FormWindowOpeningMode.LockWholeInterface);
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersCommandObject

&AtClient
Procedure CommandObjectQuickAccessPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	FastAccessChange();
EndProcedure

&AtClient
Procedure CommandObjectQuickAccessPresentationClean(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure CommandObjectScheduledJobUseOnChange(Item)
	EditScheduledJob(False, True);
EndProcedure

&AtClient
Procedure CommandObjectScheduledJobPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	EditScheduledJob(True, False);
EndProcedure

&AtClient
Procedure CommandObjectScheduledJobPresentationClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure CommandObjectSetupQuickAccess(Command)
	FastAccessChange();
EndProcedure

&AtClient
Procedure CommandObjectConfigureSchedule(Command)
	EditScheduledJob(True, False);
EndProcedure

&AtClient
Procedure CommandObjectBeforeAddingStart(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure CommandObjectBeforeDelete(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseCommand(Command)
	WriteOnClient(True);
EndProcedure

&AtClient
Procedure WriteCommand(Command)
	WriteOnClient(False);
EndProcedure

&AtClient
Procedure LoadFromFile(Command)
	UpdateFromFileStart();
EndProcedure

&AtClient
Procedure ExportToFile(Command)
	ExportParameters = New Structure;
	ExportParameters.Insert("IsReport", Object.Type = ReportKind Or Object.Type = TypeAdditionalReport);
	ExportParameters.Insert("FileName", Object.FileName);
	ExportParameters.Insert("DataProcessorDataAddress", DataProcessorDataAddress);
	AdditionalReportsAndDataProcessorsClient.ExportToFile(ExportParameters);
EndProcedure

&AtClient
Procedure AdditionalReportVariantsOpen(Command)
	Variant = ThisObject.Items.AdditionalReportVariants.CurrentData;
	If Variant = Undefined Then
		ShowMessageBox(, NStr("en = 'Choose the report version.'"));
		Return;
	EndIf;
	
	AdditionalReportsAndDataProcessorsClient.OpenAdditionalReportVariants(Object.Ref, Variant.VariantKey);
EndProcedure

&AtClient
Procedure PlaceInSections(Command)
	OptionsArray = New Array;
	For Each RowID In Items.AdditionalReportVariants.SelectedRows Do
		Variant = AdditionalReportVariants.FindByID(RowID);
		If ValueIsFilled(Variant.Ref) Then
			OptionsArray.Add(Variant.Ref);
		EndIf;
	EndDo;
	
	// Opens the dialog of placement several reports variants in command interface sections.
	If CommonUseClient.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ModuleReportsVariantsClient = CommonUseClient.CommonModule("ReportsVariantsClient");
		ModuleReportsVariantsClient.OpenPlacingVariantsInSectionsDialog(OptionsArray);
	EndIf;
EndProcedure

&AtClient
Procedure CommandPrescriptionFillingFormsClick(Item, StandardProcessing)
	StandardProcessing = False;
	
	If Object.Type = TypeAdditionalReport OR Object.Type = KindAdditionalInformationProcessor Then
		// Sections selection
		Sections = New ValueList;
		For Each TableRow In Object.Sections Do
			Sections.Add(TableRow.Section);
		EndDo;
		
		FormParameters = New Structure;
		FormParameters.Insert("Sections",      Sections);
		FormParameters.Insert("DataProcessorKind", Object.Type);
		
		OpenForm("Catalog.AdditionalReportsAndDataProcessors.Form.FillSections", FormParameters, ThisObject);
	Else
		// Choose Metadata Objects
		FormParameters = PrepareFormParametersMetadataObjectSelect();
		OpenForm("CommonForm.MetadataObjectsSelection", FormParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.CommandObjectScheduledJobUse.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.CommandObjectScheduledJobPresentation.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.Commands.RegularJobAllowed");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;

	Item.Appearance.SetParameterValue("ReadOnly", True);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure WriteOnClient(CloseAfterWriting)
	Queries = PermissionsUpdateQueries();
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, New NotifyDescription("ContinueWriteOnClient", ThisObject, CloseAfterWriting));
EndProcedure

&AtClient
Procedure ContinueWriteOnClient(Result, CloseAfterWriting)  Export
	
	WriteParameters = New Structure;
	WriteParameters.Insert("DataProcessorRegistration", DataProcessorRegistration);
	WriteParameters.Insert("CloseAfterWriting", CloseAfterWriting);
	
	Success = Write(WriteParameters);
	If Not Success Then
		Return;
	EndIf;
	
	If WriteParameters.DataProcessorRegistration Then
		RefreshReusableValues();
		Handler = New NotifyDescription("WriteOnClientEnd", ThisObject, WriteParameters);
		WarningText = NStr("en = 'For applying changes in open
		|windows it is required to close and open them again.'");
		ShowMessageBox(Handler, WarningText);
	Else
		WriteOnClientEnd(WriteParameters);
	EndIf;
	
EndProcedure

&AtServer
Function PermissionsUpdateQueries()
	
	Return AdditionalReportsAndDataProcessorsInSafeModeService.QueriesOnPermissionsForAdditionalDataProcessor(
		Object, GetPermissionsTable());
	
EndFunction

&AtClient
Procedure WriteOnClientEnd(WriteParameters) Export
	If WriteParameters.CloseAfterWriting AND IsOpen() Then
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure UpdateFromFileStart()
	RegistrationParameters = New Structure;
	RegistrationParameters.Insert("Success", False);
	RegistrationParameters.Insert("DataProcessorDataAddress", DataProcessorDataAddress);
	RegistrationParameters.Insert("ResultHandler", New NotifyDescription("UpdateFromFileEnd", ThisObject));
	Handler = New NotifyDescription("UpdateFromFileAfterFileSelection", ThisObject, RegistrationParameters);
	
	DialogueParameters = New Structure("Mode, Filter, FilterIndex, Title");
	DialogueParameters.Mode  = FileDialogMode.Open;
	DialogueParameters.Filter = AdditionalReportsAndDataProcessorsClientServer.ChooserAndSaveDialog();
	If Object.Ref.IsEmpty() Then
		DialogueParameters.FilterIndex = 0;
		DialogueParameters.Title = NStr("en = 'Select file of external report or data processor'");
	ElsIf Object.Type = TypeAdditionalReport Or Object.Type = ReportKind Then
		DialogueParameters.FilterIndex = 1;
		DialogueParameters.Title = NStr("en = 'Select file of external report'");
	Else
		DialogueParameters.FilterIndex = 2;
		DialogueParameters.Title = NStr("en = 'Select file of data processor'");
	EndIf;
	
	StandardSubsystemsClient.ShowFilePlace(Handler, UUID, Object.FileName, DialogueParameters);
EndProcedure

&AtClient
Procedure UpdateFromFileAfterFileSelection(PlacedFiles, RegistrationParameters) Export
	If PlacedFiles = Undefined Or PlacedFiles.Count() = 0 Then
		ExecuteNotifyProcessing(RegistrationParameters.ResultHandler, RegistrationParameters);
		Return;
	EndIf;
	
	FileDescription = PlacedFiles[0];
	
	Keys = New Structure("FileName, IsReport, DisablePublishing, DisableConflicts, Conflicting");
	CommonUseClientServer.ExpandStructure(RegistrationParameters, Keys, False);
	
	RegistrationParameters.DisablePublishing = False;
	RegistrationParameters.DisableConflicts = False;
	RegistrationParameters.Conflicting = New ValueList;
	
	SubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FileDescription.Name, "\");
	RegistrationParameters.FileName = SubstringArray.Get(SubstringArray.UBound());
	FileExtension = Upper(Right(RegistrationParameters.FileName, 3));
	
	If FileExtension = "ERF" Then
		RegistrationParameters.IsReport = True;
	ElsIf FileExtension = "EPF" Then
		RegistrationParameters.IsReport = False;
	Else
		RegistrationParameters.Success = False;
		StandardSubsystemsClient.ReturnResultAfterShowWarning(
			NStr("en = 'File extension does not correspond to the extension of either the external report (ERF) or processing (EPF).'"),
			RegistrationParameters.ResultHandler,
			RegistrationParameters);
		Return;
	EndIf;
	
	RegistrationParameters.DataProcessorDataAddress = FileDescription.Location;
	
	UpdateFromFileMechanicsAtClient(RegistrationParameters);
EndProcedure

&AtClient
Procedure UpdateFromFileMechanicsAtClient(RegistrationParameters)
	// Preparation to a server call.
	ResultHandler = RegistrationParameters.ResultHandler;
	RegistrationParameters.Delete("ResultHandler");
	// Server call.
	UpdateFromFileMechanicsAtServer(RegistrationParameters);
	// Cancel changes.
	RegistrationParameters.Insert("ResultHandler", ResultHandler);
	
	If RegistrationParameters.DisableConflicts Then
		// Turns off some objects because the dynamic lists must be updated.
		NotifyChanged(Type("CatalogRef.AdditionalReportsAndDataProcessors"));
	EndIf;
	
	// Server work result data processor.
	If RegistrationParameters.Success Then
		NotificationTitle = ?(RegistrationParameters.IsReport, NStr("en = 'External report file is loaded'"), NStr("en = 'External data processor file is loaded'"));
		NotificationRef    = ?(IsNew, "", GetURL(Object.Ref));
		NotificationText     = RegistrationParameters.FileName;
		ShowUserNotification(NotificationTitle, NotificationRef, NotificationText);
		ExecuteNotifyProcessing(RegistrationParameters.ResultHandler, RegistrationParameters);
	Else
		// Parsing causes of cancelling importing data processors and displaying information to user.
		If RegistrationParameters.ObjectNameUsed Then
			UpdateFromFileShowConflicts(RegistrationParameters);
		Else
			StandardSubsystemsClient.ShowExecutionResult(ThisObject, RegistrationParameters, RegistrationParameters.ResultHandler);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure UpdateFromFileShowConflicts(RegistrationParameters)
	If RegistrationParameters.ConflictsCount > 1 Then
		If RegistrationParameters.IsReport Then
			QuestionTitle = NStr("en = 'Conflicts on exporting external report'");
			QuestionText = NStr("en = 'Internal name report ""[Name]"" is already engaged other additional report ([Count]): [List].
			|
			|Select:
			|1. ""[Continue]"" - export with disabling the publication of this report.
			|2. ""[Disable]"" - export with disabling the publishing of all other conflicting reports.
			|3. ""[Open]"" - cancel exporting and open the list of conflicting reports.'");
		Else
			QuestionTitle = NStr("en = 'Conflicts when exporting external data processor'");
			QuestionText = NStr("en = 'Internal name of data processor ""[Name]"" is already occupied by other additional data processors ([Count]): [List].
			|
			|Select:
			|1. ""[Continue]"" - export with disabling publication of this data processor.
			|2. ""[Disable]"" - export with disabling the publishing of all other conflicting data processors.
			|3. ""[Open]"" - cancel exporting and open the list of conflicting data processors.'");
		EndIf;
		DisableButtonPresentation = NStr("en = 'Disconnect conflicting'");
		OpenButtonPresentation = NStr("en = 'Cancel and show list'");
	Else
		If RegistrationParameters.IsReport Then
			QuestionTitle = NStr("en = 'Conflict when exporting external report'");
			QuestionText = NStr("en = 'Internal name of report ""[Name]"" is already occupied by other additional report: [List].
			|
			|Select:
			|1. ""[Continue]"" - export with disabling the publication of this report.
			|2. ""[Disable]"" - export with disabling the publication of another report.
			|3. ""[Open]"" - cancel exporting and open another report card.'");
			DisableButtonPresentation = NStr("en = 'Disable another report'");
		Else
			QuestionTitle = NStr("en = 'Conflict when exporting external data processor'");
			QuestionText = NStr("en = 'Internal name of data processor ""[Name]"" is already occupied by another additional data processor: [List].
			|
			|Select:
			|1. ""[Continue]"" - export with disabling publication of this data processor.
			|2. ""[Disable]"" - export with disabling publishing another data processor.
			|3. ""[Open]"" - cancel exporting and open another data processor card.'");
			DisableButtonPresentation = NStr("en = 'Disable another data processor'");
		EndIf;
		OpenButtonPresentation = NStr("en = 'Cancel and open'");
	EndIf;
	ContinueButtonPresentation = NStr("en = 'In debugging mode'");
	QuestionText = StrReplace(QuestionText, "[Name]",  RegistrationParameters.ObjectName);
	QuestionText = StrReplace(QuestionText, "[Count]", RegistrationParameters.ConflictsCount);
	QuestionText = StrReplace(QuestionText, "[List]",  RegistrationParameters.LockerPresentation);
	QuestionText = StrReplace(QuestionText, "[Disable]",  DisableButtonPresentation);
	QuestionText = StrReplace(QuestionText, "[Open]",     OpenButtonPresentation);
	QuestionText = StrReplace(QuestionText, "[Continue]", ContinueButtonPresentation);
	
	QuestionButtons = New ValueList;
	QuestionButtons.Add("ContinueWithoutPublishing", ContinueButtonPresentation);
	QuestionButtons.Add("DisableConflicts",  DisableButtonPresentation);
	QuestionButtons.Add("CancelAndOpen",        OpenButtonPresentation);
	QuestionButtons.Add(DialogReturnCode.Cancel);
	
	Handler = New NotifyDescription("UpdateFromFileConflictsResolution", ThisObject, RegistrationParameters);
	
	ShowQueryBox(Handler, QuestionText, QuestionButtons, , "ContinueWithoutPublishing", QuestionTitle);
EndProcedure

&AtClient
Procedure UpdateFromFileConflictsResolution(Response, RegistrationParameters) Export
	If Response = "ContinueWithoutPublishing" Then
		// Repeated server call (publication in debug mode) and result data processor.
		RegistrationParameters.DisablePublishing = True;
		UpdateFromFileMechanicsAtClient(RegistrationParameters);
	ElsIf Response = "DisableConflicts" Then
		// Repeated server call (with conflicting transfer to debug mode) and result data processor.
		RegistrationParameters.DisableConflicts = True;
		UpdateFromFileMechanicsAtClient(RegistrationParameters);
	ElsIf Response = "CancelAndOpen" Then
		// Cancel and show conflicting.
		// List is shown when more than one item conflicts.
		ShowList = (RegistrationParameters.ConflictsCount > 1);
		If RegistrationParameters.StandardObjectName = RegistrationParameters.ObjectName AND Not IsNew Then
			// Or current item is already written with the conflicting name.
			// There will be two items in list - current and conflicting.
			// This will help to select the one to disable.
			ShowList = True;
		EndIf;
		If ShowList Then // List form with the conflicting selection.
			FormName = "Catalog.AdditionalReportsAndDataProcessors.ListForm";
			FormTitle = NStr("en = 'Additional reports and data processors with internal name ""%1""'");
			FormTitle = StrReplace(FormTitle, "%1", RegistrationParameters.ObjectName);
			ParametersForm = New Structure;
			ParametersForm.Insert("Filter", New Structure);
			ParametersForm.Filter.Insert("ObjectName", RegistrationParameters.ObjectName);
			ParametersForm.Filter.Insert("IsFolder", False);
			ParametersForm.Insert("Title", FormTitle);
			ParametersForm.Insert("Representation", "List");
		Else // Item form
			FormName = "Catalog.AdditionalReportsAndDataProcessors.ObjectForm";
			ParametersForm = New Structure;
			ParametersForm.Insert("Key", RegistrationParameters.Conflicting[0].Value);
		EndIf;
		ExecuteNotifyProcessing(RegistrationParameters.ResultHandler, RegistrationParameters);
		OpenForm(FormName, ParametersForm, Undefined, True);
	Else // Cancel.
		ExecuteNotifyProcessing(RegistrationParameters.ResultHandler, RegistrationParameters);
	EndIf;
EndProcedure

&AtClient
Procedure UpdateFromFileEnd(Result, AdditionalParameters) Export
	If Result = Undefined Or Result.Success = False Then
		If ShowDialogLoadFromFileOnOpen AND IsOpen() Then
			Close();
		EndIf;
	ElsIf Result.Success = True Then
		If Not IsOpen() Then
			Open();
		EndIf;
		Modified = True;
		DataProcessorRegistration = True;
		DataProcessorDataAddress = Result.DataProcessorDataAddress;
	EndIf;
EndProcedure

&AtClient
Procedure OpenOption()
	Variant = Items.AdditionalReportVariants.CurrentData;
	If Variant = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Variant.Ref) Then
		ErrorText = NStr("en = 'Report variant ""%1"" is not registered.'");
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorText, Variant.Description);
		ShowMessageBox(, ErrorText);
	Else
		ShowValue(, Variant.Ref);
	EndIf;
EndProcedure

&AtClient
Procedure EditScheduledJob(ChoiceMode = False, CheckBoxChanged = False)
	
	ItemCommand = Items.CommandObject.CurrentData;
	If ItemCommand = Undefined Then
		Return;
	EndIf;
	
	If ItemCommand.StartVariant <> PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.CallOfServerMethod")
		AND ItemCommand.StartVariant <> PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ScriptInSafeMode") Then
		ErrorText = NStr("en = 'Startup option command
		|""%1"" can not be used in scheduled jobs.'");
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorText, String(ItemCommand.StartVariant));
		ShowMessageBox(, ErrorText);
		If CheckBoxChanged Then
			ItemCommand.ScheduledJobUse = Not ItemCommand.ScheduledJobUse;
		EndIf;
		Return;
	EndIf;
	
	If CheckBoxChanged Then
		If Not ItemCommand.ScheduledJobUse Then
			ItemCommand.ScheduledJobPresentation = DisabledSchedulePresentation();
			Return;
		EndIf;
	EndIf;
	
	If ItemCommand.ScheduledJobSchedule.Count() > 0 Then
		CommandSchedule = ItemCommand.ScheduledJobSchedule.Get(0).Value;
	Else
		CommandSchedule = Undefined;
	EndIf;
	
	If TypeOf(CommandSchedule) <> Type("JobSchedule") Then
		CommandSchedule = New JobSchedule;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemCommand", ItemCommand);
	Handler = New NotifyDescription("EditScheduledJobEnd", ThisObject, AdditionalParameters);
	
	ScheduleEdit = New ScheduledJobDialog(CommandSchedule);
	ScheduleEdit.Show(Handler);
	
EndProcedure

&AtClient
Procedure EditScheduledJobEnd(Schedule, AdditionalParameters) Export
	If Schedule = Undefined Then
		Return;
	EndIf;
	
	ItemCommand = AdditionalParameters.ItemCommand;
	ItemCommand.ScheduledJobSchedule.Clear();
	ItemCommand.ScheduledJobSchedule.Add(Schedule);
	ItemCommand.ScheduledJobPresentation = String(Schedule);
	
	If ItemCommand.ScheduledJobPresentation = EmptySchedulePresentation() Then
		ItemCommand.ScheduledJobPresentation = DisabledSchedulePresentation();
		ItemCommand.ScheduledJobUse = False;
		Modified = True;
	Else
		ItemCommand.ScheduledJobUse = True;
	EndIf;
EndProcedure

&AtClient
Procedure FastAccessChange()
	ItemCommand = Items.CommandObject.CurrentData;
	If ItemCommand = Undefined Then
		Return;
	EndIf;
	
	Found = QuickAccess.FindRows(New Structure("CommandID", ItemCommand.ID));
	UsersWithFastAccess = New ValueList;
	For Each TableRow In Found Do
		UsersWithFastAccess.Add(TableRow.User);
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("UsersWithFastAccess", UsersWithFastAccess);
	FormParameters.Insert("CommandPresentation",         ItemCommand.Presentation);
	
	ClientCache.Insert("IDRowsCommands", ItemCommand.GetID());
	OpenForm("Catalog.AdditionalReportsAndDataProcessors.Form.QuickAccessToAdditionalReportsAndDataProcessors", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure PermissionsOnClick(Item, EventData, StandardProcessing)
	
	StandardProcessing = False;
	
	Transition = EventData.Href;
	If Not IsBlankString(Transition) Then
		AttachIdleHandler("PermissionsOnClick_Attachable", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure PermissionsOnClick_Attached()
	
	InsideProcessingKey = "internal:";
	
	If Transition = InsideProcessingKey + "home" Then
		
		PermissionsListForm();
		
	ElsIf Left(Transition, StrLen(InsideProcessingKey)) = InsideProcessingKey Then
		
		GeneratePermissionsPresentation(Right(Transition, StrLen(Transition) - StrLen(InsideProcessingKey)));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalReportVariantsBeforeDeleteEnding(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		Variant = AdditionalParameters.Variant;
		DeleteAdditionalReportOption("ExternalReport." + Object.ObjectName, Variant.VariantKey);
		AdditionalReportVariants.Delete(Variant);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client, Server

&AtClientAtServerNoContext
Function EmptySchedulePresentation()
	Return String(New JobSchedule);
EndFunction

&AtClientAtServerNoContext
Function DisabledSchedulePresentation()
	Return NStr("en = 'Schedule not specified'");
EndFunction

&AtClientAtServerNoContext
Function UsersQuickAccessPresentation(UserCount)
	If UserCount = 0 Then
		Return NStr("en = 'No'");
	EndIf;
	
	LastDigit = UserCount - 10 * Int(UserCount/10);
	
	If LastDigit = 1 Then
		QuickAccessView = NStr("en = '%1 user'");
	ElsIf LastDigit = 2 Or LastDigit = 3 Or LastDigit = 4 Then
		QuickAccessView = NStr("en = '%1 user'");
	Else
		QuickAccessView = NStr("en = '%1 of users'");
	EndIf;
	
	QuickAccessView = StringFunctionsClientServer.PlaceParametersIntoString(
		QuickAccessView, 
		Format(UserCount, "NG=0"));
	
	Return QuickAccessView;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server call, Server

&AtServer
Procedure UpdateFromFileMechanicsAtServer(RegistrationParameters)
	CatalogObject = FormAttributeToValue("Object");
	SavedCommands = CatalogObject.Commands.Unload();
	
	RegistrationResult = AdditionalReportsAndDataProcessors.RegisterDataProcessor(CatalogObject, RegistrationParameters);
	
	PermissionAdress = PutToTempStorage(CatalogObject.permissions.Unload(), ThisObject.UUID);
	ValueToFormAttribute(CatalogObject, "Object");
	
	CommonUseClientServer.ExpandStructure(RegistrationParameters, RegistrationResult, True);
	
	If RegistrationParameters.Success Then
		FillCommands(SavedCommands);
	ElsIf RegistrationParameters.ObjectNameUsed Then
		// Presentation of taken objects.
		LockerPresentation = "";
		For Each ItemOfList In RegistrationParameters.Conflicting Do
			LockerPresentation = LockerPresentation 
			+ ?(LockerPresentation = "", "", ", ")
			+ TrimAll(ItemOfList.Presentation);
			If StrLen(LockerPresentation) > 80 Then
				LockerPresentation = Left(LockerPresentation, 70) + "... ";
				Break;
			EndIf;
		EndDo;
		RegistrationParameters.Insert("LockerPresentation", LockerPresentation);
		// Quantity of taken objects.
		RegistrationParameters.Insert("ConflictsCount", RegistrationParameters.Conflicting.Count());
	Else
		If RegistrationParameters.IsReport Then
			ErrorTitle = NStr("en = 'Report is not connected'");
		Else
			ErrorTitle = NStr("en = 'Data processor is not connected'");
		EndIf;
		StandardSubsystemsClientServer.DisplayNotification(
			RegistrationParameters,
			RegistrationParameters.ErrorText,
			RegistrationParameters.BriefErrorDescription,
			ErrorTitle);
	EndIf;
	
	SetVisibleEnabled(True);
EndProcedure

&AtServer
Function PrepareFormParametersMetadataObjectSelect()
	FilterByMetadataObjects = New ValueList;
	If Object.Type = Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling Then
		CommonCommand = Metadata.CommonCommands.ObjectFilling;
	ElsIf Object.Type = Enums.AdditionalReportsAndDataProcessorsKinds.Report Then
		CommonCommand = Metadata.CommonCommands.ObjectReports;
	ElsIf Object.Type = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
		CommonCommand = Metadata.CommonCommands.ObjectAdditionalPrintForms;
	ElsIf Object.Type = Enums.AdditionalReportsAndDataProcessorsKinds.CreatingLinkedObjects Then
		CommonCommand = Metadata.CommonCommands.CreatingLinkedObjects;
	EndIf;
	For Each CommandParameterType In CommonCommand.CommandParameterType.Types() Do
		FilterByMetadataObjects.Add(Metadata.FindByType(CommandParameterType).FullName());
	EndDo;
	
	SelectedMetadataObjects = New ValueList;
	For Each PurposeItem In Object.Purpose Do
		If Not PurposeItem.ObjectDestination.DeletionMark Then
			SelectedMetadataObjects.Add(PurposeItem.ObjectDestination.FullName);
		EndIf;
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("FilterByMetadataObjects", FilterByMetadataObjects);
	FormParameters.Insert("SelectedMetadataObjects", SelectedMetadataObjects);
	FormParameters.Insert("Title", NStr("en = 'Additional processing assignment'"));
	
	Return FormParameters;
EndFunction

&AtServer
Procedure ImportSelectedMetadataObjects(Parameter)
	Object.Purpose.Clear();
	
	For Each ParameterItem In Parameter Do
		MetadataObject = Metadata.FindByFullName(ParameterItem.Value);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		PurposeRow = Object.Purpose.Add();
		PurposeRow.ObjectDestination = CommonUse.MetadataObjectID(MetadataObject);
	EndDo;
	
	Modified = True;
	SetVisibleEnabled();
EndProcedure

&AtServerNoContext
Procedure DeleteAdditionalReportOption(ObjectKey, VariantKey)
	SettingsStorages["ReportsVariantsStorage"].Delete(ObjectKey, VariantKey, Undefined);
EndProcedure

&AtServer
Procedure SetVisibleEnabled(Registration = False)
	
	If Not Registration AND Not IsNew AND Object.Type = TypeAdditionalReport Then
		AdditionalReportVariantsFill();
	Else
		AdditionalReportVariants.Clear();
	EndIf;
	
	ThisIsGlobalDataProcessor = (Object.Type = KindAdditionalInformationProcessor OR Object.Type = TypeAdditionalReport);
	IsReport = (Object.Type = TypeAdditionalReport OR Object.Type = ReportKind);
	
	VariantCount = AdditionalReportVariants.Count();
	CommandsCount = Object.Commands.Count();
	NumberOfVisibleLayers = 1;
	
	If Object.Type = TypeAdditionalReport AND Object.UsesVariantsStorage Then
		
		NumberOfVisibleLayers = NumberOfVisibleLayers + 1;
		
		Items.PagesVariants.Visible = True;
		
		If Registration OR VariantCount = 0 Then
			Items.PagesVariants.CurrentPage = Items.VariantsHideTillRecord;
			Items.PageVariants.Title = NStr("en = 'Report variants'");
		Else
			Items.PagesVariants.CurrentPage = Items.VariantsShow;
			Items.PageVariants.Title = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Report variants (%1)'"),
				Format(VariantCount, "NG="));
		EndIf;
	Else
		Items.PagesVariants.Visible = False;
	EndIf;
	
	If CommandsCount = 0 Then
		
		Items.PageCommands.Visible = False;
		Items.PageCommands.Title = NStr("en = 'Commands'");
		
	Else
		
		NumberOfVisibleLayers = NumberOfVisibleLayers + 1;
		
		Items.PageCommands.Visible = True;
		Items.PageCommands.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Commands (%1)'"),
			Format(CommandsCount, "NG="));
		
	EndIf;
	
	NumberOfPermissions = GetPermissionsTable().Count();
	PermissionsCompatibilityMode = Object.PermissionsCompatibilityMode;
	
	SafeMode = Object.SafeMode;
	If GetFunctionalOption("SaaS") Or GetFunctionalOption("SecurityProfilesAreUsed") Then
		If PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_1_3 Then
			If SafeMode AND NumberOfPermissions > 0 AND GetFunctionalOption("SecurityProfilesAreUsed") Then
				If IsNew Then
					SafeMode = "";
				Else
					SafeMode = WorkInSafeModeService.ExternalModuleConnectionMode(Object.Ref);
				EndIf;
			EndIf;
		Else
			If NumberOfPermissions = 0 Then
				SafeMode = True;
			Else
				If GetFunctionalOption("SecurityProfilesAreUsed") Then
					If IsNew Then
						SafeMode = "";
					Else
						SafeMode = WorkInSafeModeService.ExternalModuleConnectionMode(Object.Ref);
					EndIf;
				Else
					SafeMode = False;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	If NumberOfPermissions = 0 Then
		
		Items.PermissionPage.Visible = False;
		Items.GroupSafeModeGlobal.Visible = True;
		Items.DecorationSafeModeFalseLabel.Visible = (SafeMode = False);
		Items.DecorationSafeModeTrueLabel.Visible = (SafeMode = True);
		Items.GroupEnablingSecurityProfiles.Visible = False;
		
	Else
		
		NumberOfVisibleLayers = NumberOfVisibleLayers + 1;
		
		Items.PagesVariantsPermissionCommands.CurrentPage = Items.PermissionPage;
		Items.PermissionPage.Visible = True;
		Items.PermissionPage.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Permissions (%1)'"),
			Format(NumberOfPermissions, "NG="));
		
		Items.GroupSafeModeGlobal.Visible = False;
		
		If PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_1_3 Then
			Items.GroupPagesPermissionCompatibilityModes.CurrentPage = Items.PermissionPageVersion_2_1_3;
		Else
			Items.GroupPagesPermissionCompatibilityModes.CurrentPage = Items.PermissionPageVersion_2_2_2;
		EndIf;
		
		If SafeMode = True Then
			Items.PagesSafeModeWithPermissions.CurrentPage = Items.PageSafeModeWithPermissions;
		ElsIf SafeMode = False Then
			Items.PagesSafeModeWithPermissions.CurrentPage = Items.PageUnsafeModeWithPermissions;
		ElsIf TypeOf(SafeMode) = Type("String") Then
			Items.PagesSafeModeWithPermissions.CurrentPage = Items.PagePersonalSecurityProfile;
			Items.DecorationPersonalSecurityProfileLabel.Title = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Additional report or data processor will connect to
                      |application using ""personal"" security profile %1 which  allows only following operations:'"), SafeMode);
		Else
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = '%1 is not the correct connection mode for additional reports and data processors that require permissions to use security profiles!'"),
				SafeMode);
		EndIf;
		
		If SafeMode = False AND Not GetFunctionalOption("SecurityProfilesAreUsed") AND WorkInSafeModeService.SecurityProfilesSetupAvailable() Then
			Items.GroupEnablingSecurityProfiles.Visible = True;
		Else
			Items.GroupEnablingSecurityProfiles.Visible = False;
		EndIf;
		
		PermissionsListForm();
		
	EndIf;
	
	Items.PagesVariantsPermissionCommands.PagesRepresentation = FormPagesRepresentation[?(NumberOfVisibleLayers > 1, "TabsOnTop", "None")];
	
	If ThisIsGlobalDataProcessor Then
		If Object.Sections.Count() = 0 Then
			PrescriptionPresentation = NStr("en = 'Undefined'");
		Else
			PrescriptionPresentation = "";
			For Each RowSection In Object.Sections Do
				PresentationOfSection = AdditionalReportsAndDataProcessors.PresentationOfSection(RowSection.Section);
				If PresentationOfSection = Undefined Then
					Continue;
				EndIf;
				If PrescriptionPresentation = "" Then
					PrescriptionPresentation = PresentationOfSection;
				Else
					PrescriptionPresentation = PrescriptionPresentation + ", " + PresentationOfSection;
				EndIf;
			EndDo;
		EndIf;
	Else
		If Object.Purpose.Count() = 0 Then
			PrescriptionPresentation = NStr("en = 'Undefined'");
		Else
			PrescriptionPresentation = "";
			For Each PurposeRow In Object.Purpose Do
				Attributes = CommonUse.ObjectAttributesValues(PurposeRow.ObjectDestination, "Name, DeletionMark");
				If Attributes.DeletionMark Then
					Continue;
				EndIf;
				ObjectPresentation = Attributes.Description;
				If PrescriptionPresentation = "" Then
					PrescriptionPresentation = ObjectPresentation;
				Else
					PrescriptionPresentation = PrescriptionPresentation + ", " + ObjectPresentation;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	Items.CommandObjectQuickAccessPresentation.Visible       = ThisIsGlobalDataProcessor;
	Items.CommandObjectSetupQuickAccess.Visible           = ThisIsGlobalDataProcessor;
	Items.CommandObjectScheduledJobPresentation.Visible = ThisIsGlobalDataProcessor;
	Items.CommandObjectScheduledJobUse.Visible = ThisIsGlobalDataProcessor;
	Items.CommandObjectConfigureSchedule.Visible              = ThisIsGlobalDataProcessor;
	Items.CommandArrangement.Visible                              = ThisIsGlobalDataProcessor;
	Items.CommandPrescription.Visible                              = Not ThisIsGlobalDataProcessor;
	Items.FormTypes.Visible                                      = Not ThisIsGlobalDataProcessor;
	
	If IsNew Then
		Title = ?(IsReport, NStr("en = 'Additional Report (Creating)'"), NStr("en = 'Additional processing (creation)'"));
	Else
		Title = Object.Description + " " + ?(IsReport, NStr("en = '(Additional report)'"), NStr("en = '(Additional data processor)'"));
	EndIf;
	
	If VariantCount > 0 Then
		
		TableHeaderOutput = NumberOfVisibleLayers <= 1 AND Object.Type = TypeAdditionalReport AND Object.UsesVariantsStorage;
		
		Items.AdditionalReportVariants.TitleLocation = FormItemTitleLocation[?(TableHeaderOutput, "Top", "None")];
		Items.AdditionalReportVariants.Header               = Not TableHeaderOutput;
		Items.AdditionalReportVariants.HorizontalLines = Not TableHeaderOutput;
		
	EndIf;
	
	If CommandsCount > 0 Then
		
		TableHeaderOutput = NumberOfVisibleLayers <= 1 AND Not ThisIsGlobalDataProcessor;
		
		Items.CommandObject.TitleLocation = FormItemTitleLocation[?(TableHeaderOutput, "Top", "None")];
		Items.CommandObject.Header               = Not TableHeaderOutput;
		Items.CommandObject.HorizontalLines = Not TableHeaderOutput;
		
	EndIf;
	
	WindowOptionsKey = AdditionalReportsAndDataProcessors.TypeToString(Object.Type);
	
EndProcedure

&AtServer
Procedure GeneratePermissionsPresentation(Val TypePermissions)
	
	PermissionTable = GetPermissionsTable();
	AllowedString = PermissionTable.Find(TypePermissions, "TypePermissions");
	If AllowedString <> Undefined Then
		PermissionParameters = AllowedString.Parameters.Get();
		PermissionPresentation_2_1_3 = AdditionalReportsAndDataProcessorsInSafeModeService.GenerateDetailedPermissionsDescription(
			TypePermissions, PermissionParameters);
	EndIf;
	
EndProcedure

&AtServer
Procedure PermissionsListForm()
	
	PermissionTable = GetFromTempStorage(PermissionAdress);
	
	If Object.PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_1_3 Then
		
		PermissionPresentation_2_1_3 = AdditionalReportsAndDataProcessorsInSafeModeService.GeneratePermissionPresentation(PermissionTable);
		
	ElsIf Object.PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_2_2 Then
		
		permissions = New Array();
		
		For Each String In PermissionTable Do
			Resolution = XDTOFactory.Create(XDTOFactory.Type(WorkInSafeModeService.Package(), String.TypePermissions));
			FillPropertyValues(Resolution, String.Parameters.Get());
			permissions.Add(Resolution);
		EndDo;
		
		Properties = WorkInSafeModeService.PropertiesForPermissionsRegister(Object.Ref);
		
		PermissionPresentation_2_2_2 = WorkInSafeModeService.PermissionPresentationForExternalResourcesUse(
			Properties.Type, Properties.ID, Properties.Type, Properties.ID, permissions);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure FillCommands(SavedCommands = Undefined)
	
	Object.Commands.Sort("Presentation");
	
	For Each ItemCommand In Object.Commands Do
		If Object.Type = KindAdditionalInformationProcessor OR Object.Type = TypeAdditionalReport Then
			Found = QuickAccess.FindRows(New Structure("CommandID", ItemCommand.ID));
			ItemCommand.QuickAccessView = UsersQuickAccessPresentation(
				Found.Count());
		EndIf;
		
		ItemCommand.ScheduledJobUse = False;
		ItemCommand.RegularJobAllowed = False;
		
		If Object.Type = KindAdditionalInformationProcessor
			AND (ItemCommand.StartVariant = Enums.AdditionalDataProcessorsCallMethods.CallOfServerMethod
			OR ItemCommand.StartVariant = Enums.AdditionalDataProcessorsCallMethods.ScriptInSafeMode) Then
			
			ItemCommand.RegularJobAllowed = True;
			
			ScheduledJobGUID = ItemCommand.ScheduledJobGUID;
			If SavedCommands <> Undefined Then
				FoundString = SavedCommands.Find(ItemCommand.ID, "ID");
				If FoundString <> Undefined Then
					ScheduledJobGUID = FoundString.ScheduledJobGUID;
				EndIf;
			EndIf;
			
			If ValueIsFilled(ScheduledJobGUID) Then
				ScheduledJob = AdditionalReportsAndDataProcessorsScheduledJobs.FindJob(ScheduledJobGUID);
				
				If ScheduledJob <> Undefined Then
					
					JobParameters = AdditionalReportsAndDataProcessorsScheduledJobs.GetJobParameters(ScheduledJob);
					
					ItemCommand.ScheduledJobGUID = ScheduledJobGUID;
					ItemCommand.ScheduledJobPresentation = String(JobParameters.Schedule);
					ItemCommand.ScheduledJobUse = JobParameters.Use;
					ItemCommand.ScheduledJobSchedule.Insert(0, JobParameters.Schedule);
					
					If ItemCommand.ScheduledJobPresentation = EmptySchedulePresentation() Then
						ItemCommand.ScheduledJobUse = False;
					EndIf;
					
				EndIf;
			EndIf;
			
			If Not ItemCommand.ScheduledJobUse Then
				ItemCommand.ScheduledJobPresentation = DisabledSchedulePresentation();
			EndIf;
		Else
			ItemCommand.ScheduledJobPresentation = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'Not applicable for commands with ""%1"" launch variant'"),
				String(ItemCommand.StartVariant));
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure AdditionalReportVariantsFill()
	AdditionalReportVariants.Clear();
	
	Try
		ExternalObject = AdditionalReportsAndDataProcessors.GetObjectOfExternalDataProcessor(Object.Ref);
	Except
		ErrorText = NStr("en = 'Cannot get the report variant list due to an error which occurred while connecting the report:'");
		MessageText = ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo());
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndTry;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
		
		ReportMetadata = ExternalObject.Metadata();
		DCSchemaMetadata = ReportMetadata.MainDataCompositionSchema;
		If DCSchemaMetadata <> Undefined Then
			DCSchema = ExternalObject.GetTemplate(DCSchemaMetadata.Name);
			For Each DCSettingsVariant In DCSchema.SettingVariants Do
				VariantKey = DCSettingsVariant.Name;
				VariantRef = ModuleReportsVariants.GetRef(Object.Ref, VariantKey);
				If VariantRef <> Undefined Then
					Variant = AdditionalReportVariants.Add();
					Variant.VariantKey = VariantKey;
					Variant.Description = DCSettingsVariant.Presentation;
					Variant.User = False;
					Variant.PictureIndex = 5;
					Variant.Ref = VariantRef;
				EndIf;
			EndDo;
		Else
			VariantKey = "";
			VariantRef = ModuleReportsVariants.GetRef(Object.Ref, VariantKey);
			If VariantRef <> Undefined Then
				Variant = AdditionalReportVariants.Add();
				Variant.VariantKey = VariantKey;
				Variant.Description = ReportMetadata.Presentation();
				Variant.User = False;
				Variant.PictureIndex = 5;
				Variant.Ref = VariantRef;
			EndIf;
		EndIf;
	Else
		ModuleReportsVariants = Undefined;
	EndIf;
	
	If Object.UsesVariantsStorage Then
		Storage = SettingsStorages["ReportsVariantsStorage"];
		ObjectKey = Object.Ref;
	Else
		Storage = ReportsVariantsStorage;
		ObjectKey = "ExternalReport." + Object.ObjectName;
	EndIf;
	
	SettingsList = Storage.GetList(ObjectKey);
	
	For Each ItemOfList In SettingsList Do
		Variant = AdditionalReportVariants.Add();
		Variant.VariantKey = ItemOfList.Value;
		Variant.Description = ItemOfList.Presentation;
		Variant.User = True;
		Variant.PictureIndex = 3;
		If ModuleReportsVariants <> Undefined Then
			Variant.Ref = ModuleReportsVariants.GetRef(Object.Ref, Variant.VariantKey);
		EndIf;
	EndDo;
EndProcedure

&AtServer
Function GetPermissionsTable()
	
	Return GetFromTempStorage(PermissionAdress);
	
EndFunction

#EndRegion
