
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ValidateVersionAndPlatformCompatibilityMode();
	
	Parameters.Property("AdditionalInformationProcessorRef", AdditionalInformationProcessorRef);
	
	ImportDataProcessorSettings();
	ContextCall = TypeOf(Parameters.ObjectsArray) = Type("Array");
	Items.FilterObjects.Visible = Not ContextCall;
	Items.FormBack.Visible = False;
	If ContextCall Then
		FulfillActionsAtContextOpening();
	Else
		Title = NStr("en = 'Group change of attributes'");
	EndIf;
	GenerateConfiguredChangesExplanation();
	RefreshElementsVisible();
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.GroupAttributeChange.Form.AdditionalParameters") Then
		
		RefillObjectAttributesStructure = False;
		If TypeOf(ValueSelected) = Type("Structure") Then
			If IncludeHierarchy AND ProcessRecursively <> ValueSelected.ProcessRecursively Then
				ProcessRecursively = ValueSelected.ProcessRecursively;
				RefillObjectAttributesStructure = True;
				InitializeSettingsComposer();
			EndIf;
			Object.ChangeInTransaction = ValueSelected.ChangeInTransaction;
			Object.AbortOnError  = ValueSelected.AbortOnError;
			
			If Object.ShowServiceAttributes <> ValueSelected.ShowServiceAttributes Then
				Object.ShowServiceAttributes = ValueSelected.ShowServiceAttributes;
				RefillObjectAttributesStructure = True;
			EndIf;
			
			TPAboutPortionSetting          = ValueSelected.PortionSetting;
			TOObjectsPercentInPortion   = ValueSelected.ObjectsPercentageInPortion;
			TONumberOfObjectsInPortion     = ValueSelected.ObjectsCountInPortion;
			
			If RefillObjectAttributesStructure AND Not IsBlankString(ChangingObjectKind) Then
				SavedSettings = Undefined;
				ImportObjectMetadata(True, SavedSettings);
				If SavedSettings <> Undefined Then
					ConfigureChangeSetting(SavedSettings);
				EndIf;
			EndIf;
			
			RefreshElementsVisible();
		EndIf;
		
	ElsIf Upper(ChoiceSource.FormName) = Upper(FormFullNameJobsWithLockableDetails) Then
		
		If TypeOf(ValueSelected) = Type("Array") AND ValueSelected.Count() > 0 Then
			
			BlockedRowAttributes = ObjectAttributes.FindRows(New Structure("BlockedAttribute", True));
			
			For Each OperationDescriptionString IN BlockedRowAttributes Do
				If OperationDescriptionString.BlockedAttribute AND ValueSelected.Find(OperationDescriptionString.AttributeName) <> Undefined Then
					OperationDescriptionString.BlockedAttribute = False;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If TypeOf(BackgroundJobResult) = Type("Structure")
		AND Not BackgroundJobResult.JobCompleted Then
		CancelJobExecution(BackgroundJobResult.JobID);
	EndIf;

	SaveDataProcessorSettings(
			ChangingObjectKind,
			Object.ChangeInTransaction,
			Object.AbortOnError,
			TPAboutPortionSetting,
			TOObjectsPercentInPortion,
			TONumberOfObjectsInPortion,
			ProcessRecursively);
			
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ChangingObjectKindSelectionStart(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	NotifyDescription = New NotifyDescription("ChangingObjectKindSelectionMade", ThisObject);
	FormParameters = New Structure;
	FormParameters.Insert("CurrentObject", ChangingObjectKind);
	FormParameters.Insert("ShowHidden", Object.ShowServiceAttributes);
	OpenForm(FormFullName("ObjectKindSelection"), FormParameters, , , , , NotifyDescription);
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersComposerSettingsFilterSettings

&AtClient
Procedure SettingsComposerSettingsFilterOnEditEnd(Item, NewRow, CancelEdit)
	AttachIdleHandler("UpdateLabels", 1, True);
EndProcedure

&AtClient
Procedure UpdateLabels()
	UpdateLabelsServer();
EndProcedure

&AtServer
Procedure UpdateLabelsServer()
	UpdateLabelSelectedCount();
	GenerateConfiguredChangesExplanation();
EndProcedure

&AtClient
Procedure SettingsComposerSettingsFilterAfterDeleting(Item)
	UpdateLabels();
EndProcedure

&AtClient
Procedure SettingsComposerSettingsFilterWhenEditStart(Item, NewRow, Copy)
	DetachIdleHandler("UpdateLabels");
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersObjectsFailedToChange

&AtClient
Procedure ObjectsFailedToChangeBeforeChangeStart(Item, Cancel)
	Cancel = True;
	If TypeOf(Item.CurrentData.Object) <> Type("String") Then
		ShowValue(, Item.CurrentData.Object);
	EndIf;
EndProcedure

&AtClient
Procedure ObjectsFailedToChangeOnActivateRow(Item)
	If Item.CurrentData <> Undefined Then
		Cause = Item.CurrentData.Cause;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Next(Command)
	
	GoToPageOfObjectChanges();
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	ButtonFunction = "Change";
	If InProgressDataProcessor Then
		ButtonFunction = "Break";
	ElsIf DataProcessorCompleted Or Items.Pages.CurrentPage = Items.ModifyingObjects Then
		ButtonFunction = "Close";
		If ObjectsFailedToChange.Count() > 0 Then
			ButtonFunction = "Retry";
		EndIf;
	EndIf;
	
	If ButtonFunction = "Close" Then
		Close();
		Return;
	EndIf;
	
	If ButtonFunction = "Break" Then
		CurrentStateChanges.InterruptChange = True;
		If Not BackgroundJobResult.JobCompleted Then
			DetachIdleHandler("TestChange");
			FinishChangeOfObjects();
		EndIf;
		Return;
	EndIf;
	
	If ButtonFunction = "Change" Or ButtonFunction = "Retry" Then
		// Reset the cache and select objects with tabular sections.
		ObjectCountForDataProcessors = SelectedObjectsCount(True, True);
	EndIf;
	
	If ButtonFunction = "Change" Then
		If ObjectCountForDataProcessors = 0 Then
			ShowMessageBox(, NStr("en = 'Items for changing are not specified'"));
			Return;
		EndIf;
	
		If ThereAreCustomizedFilters() Then
			PerformChangingSelectionCheckIsDone();
		Else
			QuestionText = NStr("en = 'Filter is not set. Change all items?'");
			NotifyDescription = New NotifyDescription("PerformChangingSelectionCheckIsDone", ThisObject);
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.OKCancel, , , NStr("en = 'Change of elements'"));
		EndIf;
		
		Return;
	EndIf;
	
	If ButtonFunction = "Retry" Then
		PerformChangeChecksPerformed();
	EndIf;
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	BackServer();
	
EndProcedure

&AtClient
Procedure ConfigureChangeParameters(Command)
	
	FormParameters = New Structure;
	
	FormParameters.Insert("ChangeInTransaction",    Object.ChangeInTransaction);
	FormParameters.Insert("ProcessRecursively", ProcessRecursively);
	FormParameters.Insert("AbortOnError",     Object.AbortOnError);
	FormParameters.Insert("PortionSetting",        TPAboutPortionSetting);
	FormParameters.Insert("ObjectsPercentageInPortion", TOObjectsPercentInPortion);
	FormParameters.Insert("ObjectsCountInPortion",   TONumberOfObjectsInPortion);
	FormParameters.Insert("IncludeHierarchy",      IncludeHierarchy);
	FormParameters.Insert("ShowServiceAttributes",     Object.ShowServiceAttributes);
	FormParameters.Insert("ContextCall", ContextCall);
	
	OpenForm(FormFullName("AdditionalParameters"), FormParameters, ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// CONNECTED DATA PROCESSORS

&AtClient
Procedure Attachable_ValueOnChange(FormField)
	CurrentData = FormField.Parent.CurrentData;
	CurrentData.Change = ValueIsFilled(CurrentData.Value);
	UpdateChangingAttributesCounters(FormField.Parent);
	GenerateConfiguredChangesExplanation();
EndProcedure

&AtClient
Procedure Attachable_AtCheckboxChange(FormField)
	UpdateChangingAttributesCounters(FormField.Parent);
	GenerateConfiguredChangesExplanation();
EndProcedure

&AtClient
Procedure Attachable_SetSetting(Command)
	
	CommandsPlacementPlace = Items.PreviouslyModifiedAttributes;
	CommandNamePattern = CommandsPlacementPlace.Name + "ConfigurationChanges";
	IndexOfCommands = Number(Mid(Command.Name, StrLen(CommandNamePattern) + 1));
	ConfigureChangeSetting(OperationsHistoryList[IndexOfCommands].Value);
	GenerateConfiguredChangesExplanation();
	
EndProcedure

&AtClient
Procedure Attachable_BeforeChangeStart(Item, Cancel)
	
	SetLimitsForSelectedTypesAndValueSelectionParameters(Item);
	If (Item.CurrentItem = Items.ObjectAttributesValue
		Or Item.CurrentItem = Items.ObjectAttributesChange)
		AND Item.CurrentData.BlockedAttribute Then
			Cancel = True;
			QuestionGoToToAttributeUnblocking();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ObjectAttributesPresentation.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ObjectAttributes.BlockedAttribute");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", New Color(192, 192, 192));

EndProcedure

&AtClient
Procedure PerformChangingSelectionCheckIsDone(QuestionResult = Undefined, AdditionalParameters = Undefined) Export
	
	If QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Not ThereAreConfiguredChanges() Then
		QuestionText = NStr("en = 'Changes are not configured. Rewrite items without changes?'");
		NotifyDescription = New NotifyDescription("PerformChangeChecksPerformed", ThisObject);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.OKCancel, , , NStr("en = 'Change of elements'"));
	Else
		PerformChangeChecksPerformed();
	EndIf;
	
EndProcedure

&AtServer
Function ThereAreCustomizedFilters()
	For Each FilterItem IN SettingsComposer.Settings.Filter.Items Do
		If FilterItem.Use Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

&AtClient
Function FormFullName(Name)
	NameParts = DecomposeStringIntoSubstringsArray(FormName, ".");
	NameParts[3] = Name;
	Return RowFromArraySubrows(NameParts, ".");
EndFunction

&AtServer
Procedure FulfillActionsAtContextOpening()
	
	TransferedObjectType = TypeOf(Parameters.ObjectsArray[0]);
	
	For Each TransferedObject IN Parameters.ObjectsArray Do
		If TypeOf(TransferedObject) <> TransferedObjectType Then
			Raise NStr("en = 'Group change is only for items of a single type.'");
		EndIf;
	EndDo;
	
	ObjectCount    = Parameters.ObjectsArray.Count();
	CaptionPattern       = NStr("en = 'Change of selected  items ""%1"" (%2)'");
	Title = PlaceParametersIntoString(CaptionPattern, TransferedObjectType, ObjectCount);
	
	ChangeProhibitionIntegrated = Metadata.FindByFullName("CommonModule.ObjectsAttributesEditProhibitionClient") <> Undefined;
	PropertiesEmbedded = Metadata.FindByFullName("CommonModule.PropertiesManagement") <> Undefined;
	
	// IN the absence of the right to save settings it is necessary to hide all functions for settings configuring.
	Items.PreviouslyModifiedAttributes.Visible = AccessRight("SaveUserData", Metadata);
	
	Items.ChangeableAttributes.Representation = UsualGroupRepresentation.None;
	Items.ChangeableAttributes.ShowTitle = False;
	
	ObjectMetadata = Parameters.ObjectsArray[0].Metadata();
	ChangingObjectKind = ObjectMetadata.FullName();
	
	// Import history of operations with this type of objects.
	ImportHistoryOfOperations();
	FillSubmenuPreviouslyModifiedAttributes();
	
	// Hierarchical object
	IncludeHierarchy = MetadataObjectHierarchical(Parameters.ObjectsArray[0]);
	FolderHierarchy = HierarchyFoldersAndItems(Parameters.ObjectsArray[0]);
	
	SelectedObjectsInContext.LoadValues(Parameters.ObjectsArray);
	InitializeSettingsComposer();
	
	// If thre are no blocked attributes, hide AllowEditingAttributes button.
	Filter = New Structure("BlockedAttribute", True);
	
	If ChangeProhibitionIntegrated
	 AND ObjectAttributes.FindRows(Filter).Count() > 0 Then
		If ObjectMetadata.Forms.Find("AttributeUnlocking") = Undefined Then
			IsFormUnlockAttributes = False;
		Else
			IsFormUnlockAttributes = True;
			FormFullNameJobsWithLockableDetails = ChangingObjectKind + ".Form.AttributeUnlocking";
		EndIf;
	EndIf;
	
	ImportObjectMetadata();
EndProcedure

&AtClient
Procedure PerformChangeChecksPerformed(QuestionResult = Undefined, AdditionalParameters = Undefined) Export
	
	If QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	SetButtonsDuringModification(True);
	GoToPageOfObjectChanges();
	ObjectsFailedToChange.Clear();
	
	AttachIdleHandler("ChangeObjects", 0.1, True);
	
EndProcedure

&AtServer
Function ThereAreConfiguredChanges()
	Return ChangeableAttributes().Count() > 0 Or ChangeableTableParts().Count() > 0;
EndFunction

&AtServer
Procedure AddChangeToHistory(StructureChanges, ChangePresentation)
	
	// Settings of changes history is an array of structures with keys:
	// Update - array with change structure.
	// Presentation - settings presentation to user.
	Settings = CommonSettingsStorageImport(
		"GroupObjectsChange", 
		"ChangesHistory/" + ChangingObjectKind);
	
	If Settings = Undefined Then
		Settings = New Array;
	Else
		For IndexOf = 0 To Settings.UBound() Do
			If Settings.Get(IndexOf).Presentation = ChangePresentation Then
				Settings.Delete(IndexOf);
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Settings.Insert(0, New Structure("Change, Presentation", StructureChanges, ChangePresentation));
	
	If Settings.Count() > 20 Then
		Settings.Delete(19);
	EndIf;
	
	CommonSettingsStorageSave("GroupObjectsChange", "ChangesHistory/" + ChangingObjectKind, Settings);
	
	ImportHistoryOfOperations();
	FillSubmenuPreviouslyModifiedAttributes();
EndProcedure

&AtServer
Procedure ImportHistoryOfOperations()
	
	OperationsHistoryList.Clear();
	
	ChangesHistory = CommonSettingsStorageImport("GroupObjectsChange", "ChangesHistory/" + ChangingObjectKind);
	If ChangesHistory = Undefined Then
		Return;
	EndIf;
	
	For Each Setting IN ChangesHistory Do
		OperationsHistoryList.Add(Setting.Update, Setting.Presentation);
	EndDo;
	
EndProcedure

&AtClient
Procedure QuestionGoToToAttributeUnblocking()
	
	QuestionText = NStr("en = 'Attribute is locked. Do you want to proceed to the attributes unlocking?'");
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Yes'"));
	Buttons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel'"));
	
	NotifyDescription = New NotifyDescription("QuestionGoToUnblockingAttributesEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, QuestionText, Buttons, , DialogReturnCode.Yes, NStr("en = 'Attribute is locked'"));
	
EndProcedure

&AtClient
Procedure QuestionGoToUnblockingAttributesEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		AllowEditOfAttributes();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetChoiceParametersServer(ChoiceParameters, ChoiceParametersArray)
	
		For IndexOf = 1 To StrLineCount(ChoiceParameters) Do
			
			ChoiceParametersString = StrGetLine(ChoiceParameters, IndexOf);
			
			ChoiceParametersArrayOfStrings = DecomposeStringIntoSubstringsArray(ChoiceParametersString, ";");
			FieldNameFilter = TrimAll(ChoiceParametersArrayOfStrings[0]);
			TypeName       = TrimAll(ChoiceParametersArrayOfStrings[1]);
			XMLString     = TrimAll(ChoiceParametersArrayOfStrings[2]);
			
			If Type(TypeName) = Type("FixedArray") Then
				
				Array = New Array;
				
				XMLStringArray = DecomposeStringIntoSubstringsArray(XMLString, "#");
				
				For Each Item IN XMLStringArray Do
					
					ItemArray = DecomposeStringIntoSubstringsArray(Item, "*");
					
					ItemValue = XMLValue(Type(ItemArray[0]), ItemArray[1]);
					
					Array.Add(ItemValue);
					
				EndDo;
				
				Value = New FixedArray(Array);
				
			Else
				Value = XMLValue(Type(TypeName), XMLString);
			EndIf;
			
			ChoiceParametersArray.Add(New ChoiceParameter(FieldNameFilter, Value));
		
		EndDo;
	
EndProcedure

&AtServerNoContext
Procedure SaveDataProcessorSettings(DescriptionFull, ChangeInTransaction, AbortOnError,
			TPAboutPortionSetting, TOObjectsPercentInPortion, TONumberOfObjectsInPortion, ProcessRecursively)
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("ChangeInTransaction",		ChangeInTransaction);
	SettingsStructure.Insert("AbortOnError",		AbortOnError);
	SettingsStructure.Insert("TPAboutPortionSetting",			TPAboutPortionSetting);
	SettingsStructure.Insert("TOObjectsPercentInPortion",	TOObjectsPercentInPortion);
	SettingsStructure.Insert("TONumberOfObjectsInPortion",	TONumberOfObjectsInPortion);
	SettingsStructure.Insert("ProcessRecursively",	ProcessRecursively);
	
	CommonSettingsStorageSave("DataProcessor.ObjectGroupChanging", DescriptionFull, SettingsStructure);
	
EndProcedure

&AtServer
Procedure ImportDataProcessorSettings()
	
	Object.ChangeInTransaction = True;
	Object.AbortOnError  = True;
	TPAboutPortionSetting          = 1;
	TOObjectsPercentInPortion   = 100;
	TONumberOfObjectsInPortion     = 1;
	ProcessRecursively     = False;
	ShowServiceAttributes = False;
	
	SettingsStructure = CommonSettingsStorageImport(
		"DataProcessor.ObjectGroupChanging",
		ChangingObjectKind);
	
	If SettingsStructure <> Undefined Then
		Object.ChangeInTransaction = SettingsStructure.ChangeInTransaction;
		Object.AbortOnError  = SettingsStructure.AbortOnError;
		ProcessRecursively     = SettingsStructure.ProcessRecursively;
		If AccessRight("DataAdministration", Metadata) AND SettingsStructure.Property("ShowServiceAttributes") Then
			ShowServiceAttributes = SettingsStructure.ShowServiceAttributes;
		Else
			ShowServiceAttributes = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowEditOfAttributes()
	
	BlockedRowAttributes = ObjectAttributes.FindRows(
		New Structure("BlockedAttribute", True));
	
	If IsFormUnlockAttributes Then
		
		BlockedAttributes = New Array;
		
		For Each OperationDescriptionString IN BlockedRowAttributes Do
			BlockedAttributes.Add(OperationDescriptionString.AttributeName);
		EndDo;
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("BlockedAttributes", BlockedAttributes);
		OpenForm(FormFullNameJobsWithLockableDetails, FormParameters, ThisObject);
		
	Else
		
		RefArray = New Array;
		FillArrayOfEditedObjects(RefArray);
		
		SynonymsOfAttributes = New Array;
		
		For Each OperationDescriptionString IN BlockedRowAttributes Do
			SynonymsOfAttributes.Add(OperationDescriptionString.Presentation);
		EndDo;
		
		If SubsystemExists("StandardSubsystems.ObjectsAttributesEditProhibition") Then
			ObjectAttributeEditProhibitionClientModule = CommonModule("ObjectsAttributesEditProhibitionClient");
			If ObjectAttributeEditProhibitionClientModule <> Undefined Then
				ObjectAttributeEditProhibitionClientModule.CheckReferencesToObject(
					New NotifyDescription(
						"AllowEditingEndAttributes",
						ThisObject,
						BlockedRowAttributes),
					RefArray,
					SynonymsOfAttributes);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowEditingEndAttributes(Result, BlockedRowAttributes) Export
	
	If Result <> True Then
		Return;
	EndIf;
	
	For Each OperationDescriptionString IN BlockedRowAttributes Do
		OperationDescriptionString.BlockedAttribute = False;
	EndDo;
	
EndProcedure

&AtClient
Procedure GoToPageOfObjectChanges()
	
	If Items.Pages.CurrentPage = Items.ConfigurationChanges Then
		Items.Pages.CurrentPage = Items.ModifyingObjects;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetButtonsDuringModification(BeginChanges)
	
	InProgressDataProcessor = BeginChanges;

	Items.FormChange.Enabled = True;
	
	If BeginChanges Then
		Items.FormChange.Title = NStr("en = 'Break'");
	Else
		If ObjectsFailedToChange.Count() > 0 Then
			Items.FormChange.Title = NStr("en = 'Repeat changing'");
		Else
			Items.FormChange.Title = NStr("en = 'Close'");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeObjects()
	
	ClearMessages();
	CurrentStateChanges = New Structure;
	ObjectCountForDataProcessors = SelectedObjectsCount();
	
	If Object.ChangeInTransaction Then
		
		If TPAboutPortionSetting = 1 Then // processing by one call
			
			ShowUserNotification(NStr("en = 'Selected items modification'"), ,NStr("en = 'Please wait, the processing takes some time...'"));
			ShowPercentOfProcessed = False;
			
			PortionSize = ObjectCountForDataProcessors;
			
		Else
			
			ShowPercentOfProcessed = True;
			
			If TPAboutPortionSetting = 2 Then // by batches for the number of objects
				PortionSize = ?(TONumberOfObjectsInPortion < ObjectCountForDataProcessors, 
									TONumberOfObjectsInPortion, ObjectCountForDataProcessors);
			Else // IN batches by object percentage.
				PortionSize = Round(ObjectCountForDataProcessors * TOObjectsPercentInPortion / 100);
				If PortionSize = 0 Then
					PortionSize = 1;
				EndIf;
			EndIf;
			
		EndIf;
	Else
		
		If ObjectCountForDataProcessors >= NontransactionalPortionTransitionBoundary() Then
			// Objects count - constant value.
			PortionSize = NontransactionalPortionOfObtainingObjectData();
		Else
			// Objects count - variable value, common number percentage.
			PortionSize = Round(ObjectCountForDataProcessors * NontransactionalPortionOfObtainingDataPercent() / 100);
			If PortionSize = 0 Then
				PortionSize = 1;
			EndIf;
		EndIf;
		
		Status(NStr("en = 'Items are processing...'"), 0, NStr("en = 'Selected items modification'"));
		
		ShowPercentOfProcessed = True;
	EndIf;
	
	CurrentStateChanges.Insert("IsItemsForDataProcessors", True);
	// Position of the last processed item. 1 - first item.
	CurrentStateChanges.Insert("CurrentPosition", 0);
	CurrentStateChanges.Insert("ErrorsCount", 0);			// Initiate error counter
	CurrentStateChanges.Insert("CountOfChanged", 0);		// Initiate count of changed.
	CurrentStateChanges.Insert("StopChangingAtError", Object.AbortOnError);
	CurrentStateChanges.Insert("ObjectCountForDataProcessors", ObjectCountForDataProcessors);
	CurrentStateChanges.Insert("PortionSize", PortionSize);
	CurrentStateChanges.Insert("ShowPercentOfProcessed", ShowPercentOfProcessed);
	CurrentStateChanges.Insert("InterruptChange", False);
	
	AttachIdleHandler("ChangePortionOfObjects", 0.1, True);
	
	Items.Pages.CurrentPage = Items.WaitDataProcessors;
EndProcedure

&AtClient
Procedure ChangePortionOfObjects()
	
	// Change the batch on the server
	ResultOfChange = ChangeAtServer(CurrentStateChanges.StopChangingAtError);
		
	If BackgroundJobResult.JobCompleted Then
		ProcessChangeResult(GetFromTempStorage(BackgroundJobResult.StorageAddress));
	Else
		ModuleLongActionsClient = CommonModule("LongActionsClient");
		ModuleLongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("TestChange", IdleHandlerParameters.CurrentInterval, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure TestChange()
	
	Try
		BackgroundJobResult.JobCompleted = JobCompleted(BackgroundJobResult.JobID);
	Except
		GoToPageOfObjectChanges();
		Raise;
	EndTry;
	
	If BackgroundJobResult.JobCompleted Then
		ProcessChangeResult(GetFromTempStorage(BackgroundJobResult.StorageAddress));
	Else
		ModuleLongActionsClient = CommonModule("LongActionsClient");
		ModuleLongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("TestChange", IdleHandlerParameters.CurrentInterval, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessChangeResult(ResultOfChange = Undefined, ContinueProcessing = Undefined)
	Var ErrorsCount, CountOfChanged;
	
	If ContinueProcessing = Undefined Then
		ContinueProcessing = True;
	EndIf;
	
	While ContinueProcessing Do
		// Transfer information of processed objects to the table.
		FillStateOfProcessed(ResultOfChange, ErrorsCount, CountOfChanged);
		
		CurrentStateChanges.ErrorsCount = ErrorsCount + CurrentStateChanges.ErrorsCount;
		CurrentStateChanges.CountOfChanged = CountOfChanged + CurrentStateChanges.CountOfChanged;
		
		If Not (CurrentStateChanges.StopChangingAtError AND ResultOfChange.HasErrors) Then
			Break;
		EndIf;
		
		// If there are errors in transaction - Roll the whole transaction back.
		If Object.ChangeInTransaction Then
			WarningText = NStr("en = 'At the items modification the errors have occurred - changes have been cancelled.'");
			AttachIdleHandler("FinishChangeOfObjects", 0.1, True);
			Return; // Early exit from the cycle and procedure.
		EndIf;
		
		QuestionText = NStr("en = 'Errors occurred while changing items (item groups).
			|Do you want to terminate the items modification and proceed to the errors viewing?
			|'");
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Abort, NStr("en = 'Break'"));
		Buttons.Add(DialogReturnCode.Ignore, NStr("en = 'Continue'"));
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Don''t ask again'"));
		
		NotifyDescription = New NotifyDescription("ProcessChangeResultResponseReceived", ThisObject, ResultOfChange);
		ShowQueryBox(NOTifyDescription, QuestionText, Buttons, , DialogReturnCode.Abort, NStr("en = 'Errors when changing the items'"));
		Return;
	EndDo;
	
	CurrentStateChanges.CurrentPosition = CurrentStateChanges.CurrentPosition + CurrentStateChanges.PortionSize;
	
	If CurrentStateChanges.ShowPercentOfProcessed Then
		// Calculate the current percentage of processed objects.
		CurrentPercent = Round(CurrentStateChanges.CurrentPosition / CurrentStateChanges.ObjectCountForDataProcessors * 100);
		Status(NStr("en = 'Items are processing...'"), CurrentPercent, NStr("en = 'Selected items modification'"));
	EndIf;
	
	IsItemsForDataProcessors = ?(CurrentStateChanges.CurrentPosition < CurrentStateChanges.ObjectCountForDataProcessors, True, False);
	
	If IsItemsForDataProcessors AND Not CurrentStateChanges.InterruptChange Then
		AttachIdleHandler("ChangePortionOfObjects", 0.1, True);
	Else
		AttachIdleHandler("FinishChangeOfObjects", 0.1, True);
	EndIf;

EndProcedure

&AtClient
Procedure ProcessChangeResultResponseReceived(QuestionResult, ResultOfChange) Export
	
	If QuestionResult = Undefined Or QuestionResult = DialogReturnCode.Abort Then
		AttachIdleHandler("FinishChangeOfObjects", 0.1, True);
		Return;
	ElsIf QuestionResult = DialogReturnCode.No Then
		CurrentStateChanges.StopChangingAtError = False;
	EndIf;
	
	ProcessChangeResult(ResultOfChange, False);
	
EndProcedure

&AtClient
Procedure FinishChangeOfObjects()
	
	SetButtonsDuringModification(False);
	FinalizingActionsOnChangeServer();
	NotifyChanged(ChangingObjectsType());
	Notify("CompletionOfGroupChangesObjects");
	
	DataProcessorCompleted = CurrentStateChanges.CountOfChanged = CurrentStateChanges.ObjectCountForDataProcessors;
	If DataProcessorCompleted Then
		ShowUserNotification(NStr("en = 'Item attribute changing'"), , 
			PlaceParametersIntoString(NStr("en = 'changed items (%1).'"), CurrentStateChanges.CountOfChanged));
		GoToPageAllDone();
		Return;
	EndIf;
	
	Items.GroupObjectsFailedToChange.Visible = ObjectsFailedToChange.Count() > 0;
	
	If DataProcessorCompleted Then
		MessagePattern = NStr("en = 'Changes are done for all selected items (%2).'");
	Else
		If Object.ChangeInTransaction Or CurrentStateChanges.CountOfChanged = 0 Then
			MessagePattern = NStr("en = 'Changes are not performed'");
		Else
			MessagePattern = NStr("en = 'Partly modified.
										|Modified: %1; Failed to change: %3'");
		EndIf;
	EndIf;
	
	If Object.ChangeInTransaction AND Not DataProcessorCompleted Then
		SkippedQuantity = CurrentStateChanges.ObjectCountForDataProcessors - CurrentStateChanges.ErrorsCount;
		If SkippedQuantity > 0 AND Not CurrentStateChanges.InterruptChange Then
			TableRow = ObjectsFailedToChange.Add();
			TableRow.Object = PlaceParametersIntoString(NStr("en = '... and other items (%1)'"), SkippedQuantity);
			TableRow.Cause = NStr("en = 'Skipped since one or more items were not changed.'");
		EndIf;
	EndIf;
	
	Items.LabelDataProcessorResults.Title = PlaceParametersIntoString(
		MessagePattern,
		CurrentStateChanges.CountOfChanged,
		CurrentStateChanges.ObjectCountForDataProcessors,
		CurrentStateChanges.ErrorsCount);
		
	Items.FormBack.Visible = True;
	
	CurrentStateChanges = Undefined;
	
EndProcedure

&AtServer
Procedure BackServer()
	
	If Items.Pages.CurrentPage = Items.ModifyingObjects 
		Or Items.Pages.CurrentPage = Items.AllDone Then
		Items.Pages.CurrentPage = Items.ConfigurationChanges;
	EndIf;
	
	DataProcessorCompleted = False;
	ObjectsFailedToChange.Clear();
	Items.FormBack.Visible = False;
	Items.FormChange.Title = NStr("en = 'Change attributes'");
	
	UpdateLabelsServer();
	
EndProcedure

&AtServer
Procedure GoToPageAllDone()
	
	Items.Pages.CurrentPage = Items.AllDone;
	Items.LabelSuccessfullyCompleted.Title = PlaceParametersIntoString(
		NStr("en = 'Attributes of selected items were changed.
			|Total modified items:% 1'"), CurrentStateChanges.CountOfChanged);
	Items.FormChange.Title = NStr("en = 'Done'");
	Items.FormBack.Visible = True;
	
EndProcedure

&AtServer
Function ChangingObjectsType()
	ObjectManager = ObjectManagerByFullName(ChangingObjectKind);
	Return TypeOf(ObjectManager.EmptyRef());
EndFunction

&AtServer
Procedure FinalizingActionsOnChangeServer()
	If BackgroundJobResult.Property("JobID") Then
		LongActionsModule = CommonModule("LongActions");
		LongActionsModule.CancelJobExecution(BackgroundJobResult.JobID);
	EndIf;
	
	Items.Pages.CurrentPage = Items.ModifyingObjects;
	SaveCurrentChangeSettings();
EndProcedure

&AtServer
Procedure SaveCurrentChangeSettings()
	
	CurrentSettings = CurrentSettingsChanges();
	If CurrentSettings <> Undefined Then
		AddChangeToHistory(CurrentSettings.DescriptionOfChange, CurrentSettings.ChangePresentation);
	EndIf;
	
EndProcedure

&AtServer
Function CurrentSettingsChanges()
	
	DescriptionOfChange = New Structure;
	CollectionOfOperations = ObjectAttributes.FindRows(New Structure("Change", True));
	
	PresentationPattern = "[Field] = <Value>";
	ChangePresentation = "";
	
	AttributeChangeSettings = New Array;
	For Each OperationDescription IN CollectionOfOperations Do
		StructureChanges = New Structure;
		StructureChanges.Insert("OperationKind", OperationDescription.OperationKind);
		StructureChanges.Insert("AttributeName", OperationDescription.Name);
		StructureChanges.Insert("Property", OperationDescription.Property);
		StructureChanges.Insert("Value", OperationDescription.Value);
		AttributeChangeSettings.Add(StructureChanges);
		
		ValueByString = TrimAll(String(OperationDescription.Value));
		If IsBlankString(ValueByString) Then
			ValueByString = """""";
		EndIf;
		Update = StrReplace(PresentationPattern, "[Field]", TrimAll(String(OperationDescription.Presentation)));
		Update = StrReplace(Update, "<Value>", ValueByString);
		
		If Not IsBlankString(ChangePresentation) Then
			ChangePresentation = ChangePresentation + "; ";
		EndIf;
		ChangePresentation = ChangePresentation + Update;
	EndDo;
	DescriptionOfChange.Insert("Attributes", AttributeChangeSettings);
	
	TablePartChangeSettings = New Structure;
	For Each TabularSection IN ChangeableTableParts() Do
		If Not IsBlankString(ChangePresentation) Then
			ChangePresentation = ChangePresentation + "; ";
		EndIf;
		ChangePresentation = ChangePresentation + TabularSection.Key + " (";
		AttributeChangeSettings = New Array;
		AttributesString = "";
		For Each Attribute IN TabularSection.Value Do
			StructureChanges = New Structure("Name,Value");
			FillPropertyValues(StructureChanges, Attribute);
			AttributeChangeSettings.Add(StructureChanges);
			
			Update = StrReplace(PresentationPattern, "[Field]", TrimAll(String(Attribute.Presentation)));
			Update = StrReplace(Update, "<Value>", TrimAll(String(Attribute.Value)));
			
			If Not IsBlankString(AttributesString) Then
				AttributesString = AttributesString + "; ";
			EndIf;
			AttributesString = AttributesString + Update;
		EndDo;
		ChangePresentation = ChangePresentation + AttributesString + ")";
		TablePartChangeSettings.Insert(TabularSection.Key, AttributeChangeSettings);
	EndDo;
	
	DescriptionOfChange.Insert("TabularSections", TablePartChangeSettings);
	
	Result = Undefined;
	If ValueIsFilled(ChangePresentation) Then
		Result = New Structure;
		Result.Insert("DescriptionOfChange", DescriptionOfChange);
		Result.Insert("ChangePresentation", ChangePresentation);
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure FillStateOfProcessed(ResultOfChange, ErrorsCount, CountOfChanged)
	
	ErrorsCount = 0;
	CountOfChanged = 0;
	
	For Each StateProcessedObject IN ResultOfChange.ProcessingState Do
		LineNumber = -1;
		If Not IsBlankString(StateProcessedObject.Value.ErrorCode) Then
			ErrorsCount = ErrorsCount + 1;
			
			ErrorRecord = ObjectsFailedToChange.Add();
			ErrorRecord.Object = StateProcessedObject.Key;
			ErrorRecord.Cause = StateProcessedObject.Value.ErrorInfo;
		Else
			CountOfChanged = CountOfChanged + 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function NextObjetBatchToBeChanged()
	
	BeginSelection = CurrentStateChanges.CurrentPosition;
	EndSelection = CurrentStateChanges.CurrentPosition + CurrentStateChanges.PortionSize - 1;
	
	SelectedObjects = SelectedObjects();
	If EndSelection > SelectedObjects.Rows.Count() - 1 Then
		EndSelection = SelectedObjects.Rows.Count() - 1;
	EndIf;
	
	Result = New ValueTree;
	For Each Column IN SelectedObjects.Columns Do
		Result.Columns.Add(Column.Name, Column.ValueType);
	EndDo;
	
	For IndexOf = BeginSelection To EndSelection Do
		ObjectDescription = Result.Rows.Add();
		FillPropertyValues(ObjectDescription, SelectedObjects.Rows[IndexOf]);
		For Each ObjectString IN SelectedObjects.Rows[IndexOf].Rows Do
			FillPropertyValues(ObjectDescription.Rows.Add(), ObjectString);
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function ChangeableAttributes(TabularSectionName = "ObjectAttributes")
	AttributesTable = ThisObject[TabularSectionName];
	Return ValueTableToArray(AttributesTable.Unload(New Structure("Change", True)));
EndFunction

&AtServer
Function ChangeableTableParts()
	Result = New Structure;
	For Each TabularSection IN ObjectTabularSections Do
		ChangeableAttributes = ChangeableAttributes(TabularSection.Value);
		If ChangeableAttributes.Count() > 0 Then
			TabularSectionName = Mid(TabularSection.Value, StrLen("TabularSection") + 1);
			Result.Insert(TabularSectionName, ChangeableAttributes);
		EndIf;
	EndDo;
	Return Result;
EndFunction

&AtServer
Function ChangeAtServer(Val StopChangingAtError)
	
	ObjectsForProcessings = NextObjetBatchToBeChanged();
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ProcessedObjects", New ValueStorage(ObjectsForProcessings));
	ParametersStructure.Insert("StopChangingAtError", StopChangingAtError);
	ParametersStructure.Insert("ChangeInTransaction", DataProcessorObject.ChangeInTransaction);
	ParametersStructure.Insert("AbortOnError", DataProcessorObject.AbortOnError);
	ParametersStructure.Insert("UsedAdditAttributes", DataProcessorObject.UsedAdditAttributes);
	ParametersStructure.Insert("UsedAdditInfo", DataProcessorObject.UsedAdditInfo);
	ParametersStructure.Insert("ChangeableAttributes", ChangeableAttributes());
	ParametersStructure.Insert("ChangeableTableParts", ChangeableTableParts());
	ParametersStructure.Insert("ObjectsForChange", New ValueStorage(SelectedObjects()));
	
	IsExternalDataProcessor = Not Metadata.DataProcessors.Contains(DataProcessorObject.Metadata());
	If Not Object.ChangeInTransaction Or Not SubsystemExists("StandardSubsystems.BasicFunctionality") Then
			StorageAddress = PutToTempStorage(Undefined, UUID);
			DataProcessorObject.RunChangeOfObjects(ParametersStructure, StorageAddress);
			BackgroundJobResult = New Structure("TaskDone, StorageAddress", True, StorageAddress);
	Else
		JobDescription = NStr("en = 'Item group changing'");
		
		RunningMethod = "LongActionsPerformObjectModuleProcessingProcedure";
		ParametersStructure = New Structure("DataProcessorName,MethodName,ExecuteParameters,IsExternalDataProcessor,AdditionalInformationProcessorRef",
			DataProcessorName(), "RunChangeOfObjects", ParametersStructure, IsExternalDataProcessor, AdditionalInformationProcessorRef);
		
		LongActionsModule = CommonModule("LongActions");
		BackgroundJobResult = LongActionsModule.ExecuteInBackground(
			UUID,
			RunningMethod,
			ParametersStructure, 
			JobDescription);
	EndIf;
	
	Return BackgroundJobResult;
	
EndFunction

&AtServer
Function DataProcessorName()
	DataProcessorObject = FormAttributeToValue("Object");
	IsExternalDataProcessor = Not Metadata.DataProcessors.Contains(DataProcessorObject.Metadata());
	NameParts = DecomposeStringIntoSubstringsArray(FormName, ".");
	If IsExternalDataProcessor Then
		Return DataProcessorObject.UsedFileName;
	Else
		Return NameParts[1];
	EndIf;
EndFunction

&AtServer
Procedure FillArrayOfEditedObjects(RefArray)
	
	For Each SelectedObject IN SelectedObjects().Rows Do
		RefArray.Add(SelectedObject.Ref);
	EndDo;
	
EndProcedure

&AtClient
Procedure SetDeletionMarkValue(ItemCollection, Value)
	
	For Each CollectionItem IN ItemCollection Do
		CollectionItem.Change = Value;
		SetDeletionMarkValue(CollectionItem.GetItems(), Value);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function MetadataObjectHierarchical(RefOfFirst)
	
	ObjectKindByRef = ObjectKindByRef(RefOfFirst);
	
	If ((ObjectKindByRef = "Catalog" OR ObjectKindByRef = "ChartOfCharacteristicTypes") AND RefOfFirst.Metadata().Hierarchical)
	 OR (ObjectKindByRef = "ChartOfAccounts") Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

&AtServerNoContext
Function HierarchyFoldersAndItems(RefOfFirst)
	
	ObjectKindByRef = ObjectKindByRef(RefOfFirst);
	
	If   (ObjectKindByRef = "Catalog"
	      AND RefOfFirst.Metadata().Hierarchical
	      AND RefOfFirst.Metadata().HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems)
	   OR (ObjectKindByRef = "ChartOfCharacteristicTypes"
	      AND RefOfFirst.Metadata().Hierarchical)
	   Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

&AtClientAtServerNoContext
Function NontransactionalPortionTransitionBoundary()
	
	Return 100; // If there are more than 100
				 // objects to be changed in the
				 // list, the change is performed for a constant number of objects, see . NontransactionalBatchOfObjectDataReceiving().
	
EndFunction

&AtClientAtServerNoContext
Function NontransactionalPortionOfObtainingDataPercent()
	
	Return 10;	// If there are less than 100
				// objects to be changed in the list, they are changed by batches based on object percent of total amount.
	
EndFunction

&AtClientAtServerNoContext
Function NontransactionalPortionOfObtainingObjectData()
	
	Return 10;	// If there are more than 100
				// objects to be changed in
				// the list, they are changed by batches based on constant number of objects.
	
EndFunction

&AtServerNoContext
Function JobCompleted(JobID)
	
	LongActionsModule = CommonModule("LongActions");
	Return LongActionsModule.JobCompleted(JobID);
	
EndFunction

&AtClient
Procedure ResetChangeSettings()
	For Each Attribute IN ObjectAttributes Do
		Attribute.Value = Undefined;
		Attribute.Change = False;
	EndDo;
	
	For Each TabularSection IN ObjectTabularSections Do
		For Each Attribute IN ThisObject[TabularSection.Value] Do
			Attribute.Value = Undefined;
			Attribute.Change = False;
		EndDo;
	EndDo;	
EndProcedure

&AtServerNoContext
Procedure CancelJobExecution(JobID);
	LongActionsModule = CommonModule("LongActions");
	LongActionsModule.CancelJobExecution(JobID);
EndProcedure

&AtClient
Procedure FilterSettingsClick(Item)
	If Not IsBlankString(ChangingObjectKind) Then
		NotifyDescription = New NotifyDescription("OnCloseSelectedObjectsForm", ThisObject);
		OpenForm(FormFullName("SelectedItems"), 
			New Structure("ChangingObjectKind, Settings", ChangingObjectKind, SettingsComposer.Settings), , , , , NotifyDescription);
	EndIf;
EndProcedure

&AtClient
Procedure OnCloseSelectedObjectsForm(Settings, AdditionalParameters) Export
	If TypeOf(Settings) = Type("DataCompositionSettings") Then
		SettingsComposer.LoadSettings(Settings);
		UpdateLabels();
	EndIf;
EndProcedure

&AtServer
Function SelectedObjects(RefreshList = False, IncludeTablePartsInSampling = False, ErrorMessageText = "")
	
	If Not RefreshList AND Not IsBlankString(SelectedListAddress) Then
		Return GetFromTempStorage(SelectedListAddress);
	EndIf;
		
	Result = New ValueTree;
	
	If Not IsBlankString(ChangingObjectKind) Then
		MetadataObject = Metadata.FindByFullName(ChangingObjectKind);
		ObjectDataProcessor = FormAttributeToValue("Object");
		QueryText = ObjectDataProcessor.QueryText(MetadataObject);
		DataCompositionSchema = DataCompositionSchema(QueryText);
		
		DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
		SchemaURL = PutToTempStorage(DataCompositionSchema, UUID);
		DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
		DataCompositionSettingsComposer.LoadSettings(SettingsComposer.Settings);
		If IncludeTablePartsInSampling Then
			ConfigureOutputStructureSetting(DataCompositionSettingsComposer.Settings, IncludeTablePartsInSampling);
		EndIf;
		
		If ObjectsFailedToChange.Count() > 0 AND Not Object.ChangeInTransaction Then // repeat for unmodified
			FilterItem = DataCompositionSettingsComposer.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue = New DataCompositionField("Ref");
			FilterItem.ComparisonType = DataCompositionComparisonType.InList;
			FilterItem.RightValue = New ValueList;
			FilterItem.RightValue.LoadValues(ObjectsFailedToChange.Unload().UnloadColumn("Object"));
		EndIf;
		
		Result = New ValueTree;
		TemplateComposer = New DataCompositionTemplateComposer;
		Try
			DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema,
				DataCompositionSettingsComposer.Settings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
		Except
			ErrorMessageText = BriefErrorDescription(ErrorInfo());
			Return Result;
		EndTry;
			
		DataCompositionProcessor = New DataCompositionProcessor;
		DataCompositionProcessor.Initialize(DataCompositionTemplate);

		OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
		OutputProcessor.SetObject(Result);
		OutputProcessor.Output(DataCompositionProcessor);
		SelectedListAddress = PutToTempStorage(Result, UUID);
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure ConfigureOutputStructureSetting(Settings, ToBeChanged = False)
	
	Settings.Structure.Clear();
	Settings.Selection.Items.Clear();
	
	DataCompositionGroup = Settings.Structure.Add(Type("DataCompositionGroup"));
	DataCompositionGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	DataCompositionGroup.Use = True;
	
	GroupingField = DataCompositionGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	GroupingField.Field = New DataCompositionField("Ref");
	GroupingField.Use = True;
	
	ComboBox = Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
	ComboBox.Field = New DataCompositionField("Ref");
	ComboBox.Use = True;
	
	If ToBeChanged Then
		MetadataObject = Metadata.FindByFullName(ChangingObjectKind);
		For Each TabularSection IN MetadataObject.TabularSections Do
			TabularSectionName = TabularSection.Name;
			
			TableGrouping = DataCompositionGroup.Structure.Add(Type("DataCompositionGroup"));
			TableGrouping.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
			TableGrouping.Use = True;
			
			GroupingField = TableGrouping.GroupFields.Items.Add(Type("DataCompositionGroupField"));
			GroupingField.Field = New DataCompositionField(TabularSectionName + ".LineNumber");
			GroupingField.Use = True;
			
			ComboBox = Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
			ComboBox.Field = New DataCompositionField(TabularSectionName + ".LineNumber");
			ComboBox.Use = True;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Function SelectedObjectsCount(Recalculate = False, ToBeChanged = False, ErrorMessageText = "")
	
	Return SelectedObjects(Recalculate, ToBeChanged, ErrorMessageText).Rows.Count();
	
EndFunction

&AtServer
Function DataCompositionSchema(QueryText)
	
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.DataSource = "DataSource1";
	DataSet.AutoFillAvailableFields = True;
	DataSet.Query = QueryText;
	DataSet.Name = "DataSet1";
	
	Return DataCompositionSchema;
	
EndFunction

&AtClient
Procedure ChangingObjectKindSelectionMade(SelectedObject, AdditionalParameters) Export
	If SelectedObject <> Undefined AND ChangingObjectKind <> SelectedObject Then
		ChangingObjectKind = SelectedObject;
		RebuildFormInterfaceForSelectedObjectKind();
	EndIf;
EndProcedure

&AtServer
Procedure RebuildFormInterfaceForSelectedObjectKind()
	InitiateFormSettings();
	RefreshElementsVisible();
	GenerateConfiguredChangesExplanation();
EndProcedure

&AtServer
Procedure InitiateFormSettings()
	InitializeSettingsComposer();
	ImportObjectMetadata();
	ImportHistoryOfOperations();
	FillSubmenuPreviouslyModifiedAttributes();
	ChangeableObjectsPresentation = ChangeableObjectsPresentation();
	UpdateLabelsServer();
EndProcedure

&AtServer
Function ChangeableObjectsPresentation()
	MetadataObject = Metadata.FindByFullName(ChangingObjectKind);
	Result = MetadataObject.Presentation();
	Return Result;
EndFunction

&AtServer
Procedure InitializeSettingsComposer()
	MetadataObject = Metadata.FindByFullName(ChangingObjectKind);
	ObjectDataProcessor = FormAttributeToValue("Object");
	QueryText = ObjectDataProcessor.QueryText(MetadataObject);
	DataCompositionSchema = DataCompositionSchema(QueryText);
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(PutToTempStorage(DataCompositionSchema, UUID)));
	SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	ConfigureOutputStructureSetting(SettingsComposer.Settings);
	
	If SelectedObjectsInContext.Count() > 0 Then
		FilterItem = SettingsComposer.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("Ref");
		If IncludeHierarchy AND ProcessRecursively Then
			FilterItem.ComparisonType = DataCompositionComparisonType.InListByHierarchy;
		Else
			FilterItem.ComparisonType = DataCompositionComparisonType.InList;
		EndIf;
		FilterItem.RightValue = New ValueList;
		FilterItem.RightValue.LoadValues(SelectedObjectsInContext.UnloadValues());
	EndIf;
EndProcedure

&AtServer
Procedure ClearObjectInformation()
	FormAttributesToBeDeleted = New Array;
	For Each TabularSection IN ObjectTabularSections Do
		FormAttributesToBeDeleted.Add(TabularSection.Value);
		Items.Delete(Items.Find("Page" + TabularSection.Value));
	EndDo;
	ChangeAttributes(, FormAttributesToBeDeleted);
	ObjectTabularSections.Clear();
EndProcedure

&AtServer
Procedure ImportObjectMetadata(SaveCurrentChangeSettings = False, SavedSettings = Undefined)
	
	If SaveCurrentChangeSettings Then
		CurrentSettings =  CurrentSettingsChanges();
		If CurrentSettings <> Undefined Then
			SavedSettings = CurrentSettings.DescriptionOfChange;
		EndIf;
	EndIf;
	
	ClearObjectInformation();
	
	BlockedAttributes = BlockedAttributes();
	NonEditableAttributes = NonEditableAttributes();
	FilteredAttributes = FilteredAttributes();
	
	FillObjectAttributes(BlockedAttributes, NonEditableAttributes, FilteredAttributes);
	If Not ContextCall Then
		FillObjectTableParts(BlockedAttributes, NonEditableAttributes, FilteredAttributes);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ObjectManagerMethodsForBlockingAttributes(ObjectName)
	
	ModuleStandardSubsystemIntegration = CommonModule("StandardSubsystemsIntegration");
	ModuleObjectsAttributesEditProhibitionOverridable = CommonModule("ObjectsAttributesEditProhibitionOverridable");
	If ModuleStandardSubsystemIntegration = Undefined Or ModuleObjectsAttributesEditProhibitionOverridable = Undefined Then
		Return New Array;
	EndIf;
	
	ObjectsWithLockedAttributes = New Map;
	ModuleStandardSubsystemIntegration.OnDetermineObjectsWithLockedAttributes(ObjectsWithLockedAttributes);
	ModuleObjectsAttributesEditProhibitionOverridable.OnDetermineObjectsWithLockedAttributes(ObjectsWithLockedAttributes);
	
	ObjectManagerInfo = ObjectsWithLockedAttributes[ObjectName];
	If ObjectManagerInfo = Undefined Then
		Return "NotSupported";
	EndIf;
	AvailableMethods = DecomposeStringIntoSubstringsArray(ObjectManagerInfo, Chars.LF, True);
	Return AvailableMethods;
	
EndFunction

&AtServer
Function BlockedAttributes()
	
	Result = New Array;
	
	If SSLVersionMeetsRequirements() Then
		
		AvailableMethods = ObjectManagerMethodsForBlockingAttributes(ChangingObjectKind);
		If TypeOf(AvailableMethods) = Type("Array") AND (AvailableMethods.Count() = 0 
			OR AvailableMethods.Find("GetObjectAttributesBeingLocked") <> Undefined) Then 
			
			ObjectManager = ObjectManagerByFullName(ChangingObjectKind);
			AttributesToLockDetails = ObjectManager.GetObjectAttributesBeingLocked();
			
		EndIf;
		
	Else	
		
		// IN configurations without SSL or for old SSL versions you shall try to determine whether there are lockable  attributes in the object ("No-edit order for the object attributes").
		ObjectManager = ObjectManagerByFullName(ChangingObjectKind);
		
		Try
			AttributesToLockDetails = ObjectManager.GetObjectAttributesBeingLocked();
		Except
			// method is not found
			AttributesToLockDetails = Undefined;
		EndTry;
		
	EndIf;
	
	If AttributesToLockDetails <> Undefined Then
		For Each LockAttributeDetails IN AttributesToLockDetails Do
			Result.Add(TrimAll(DecomposeStringIntoSubstringsArray(LockAttributeDetails, ";")[0]));
		EndDo;
	EndIf;
	Return Result;
	
EndFunction

&AtServerNoContext
Function ObjectManagerMethodsForEditingDetails(ObjectName)
	
	ModuleStandardSubsystemIntegration = CommonModule("StandardSubsystemsIntegration");
	ModuleGroupObjectChangeOverridable = CommonModule("GroupObjectChangeOverridable");
	If ModuleStandardSubsystemIntegration = Undefined Or ModuleGroupObjectChangeOverridable = Undefined Then
		Return New Array;
	EndIf;
	
	ObjectsWithLockedAttributes = New Map;
	ModuleStandardSubsystemIntegration.WhenDefiningObjectsWithEditableAttributes(ObjectsWithLockedAttributes);
	ModuleGroupObjectChangeOverridable.WhenDefiningObjectsWithEditableAttributes(ObjectsWithLockedAttributes);
	
	ObjectManagerInfo = ObjectsWithLockedAttributes[ObjectName];
	If ObjectManagerInfo = Undefined Then
		Return "NotSupported";
	EndIf;
	AvailableMethods = DecomposeStringIntoSubstringsArray(ObjectManagerInfo, Chars.LF, True);
	Return AvailableMethods;
	
EndFunction

&AtServer
Function NonEditableAttributes()
	
	If Object.ShowServiceAttributes Then
		Return New Array;
	EndIf;
	
	SSLVersionMeetsRequirements = SSLVersionMeetsRequirements();
	If SSLVersionMeetsRequirements Then
		AvailableMethods = ObjectManagerMethodsForEditingDetails(ChangingObjectKind);
		If TypeOf(AvailableMethods) = Type("Array") AND (AvailableMethods.Count() = 0 OR 
			AvailableMethods.Find("NotEditableInGroupProcessingAttributes") <> Undefined) Then
			
			ObjectManager = ObjectManagerByFullName(ChangingObjectKind);
			NotEditable = ObjectManager.NotEditableInGroupProcessingAttributes();
			
		Else 
			NotEditable = New Array;
		EndIf;
	Else
		// For configurations without SSL or SSL in old versions try to determine whether there are noneditable attributes of the object.
		ObjectManager = ObjectManagerByFullName(ChangingObjectKind);
		Try
			NotEditable = ObjectManager.NotEditableInGroupProcessingAttributes();
		Except
			// method is not found
			NotEditable = New Array;
		EndTry;
	EndIf;
		
	If NotEditable.Count() > 0 Then
		Return NotEditable;
	EndIf;
	
	If SSLVersionMeetsRequirements Then
		If TypeOf(AvailableMethods) = Type("Array") AND (AvailableMethods.Count() = 0 OR 
			AvailableMethods.Find("EditedAttributesInGroupDataProcessing") <> Undefined) Then 
			
			If ObjectManager = Undefined Then
				ObjectManager = ObjectManagerByFullName(ChangingObjectKind);
			EndIf;
			editable = ObjectManager.EditedAttributesInGroupDataProcessing();
		Else 
			editable = Undefined;
		EndIf;
	Else
		// For configurations without SSL or SSL in old versions try to determine whether there are editable attributes of the object.
		Try
			editable = ObjectManager.EditedAttributesInGroupDataProcessing();
		Except
			editable = Undefined;
		EndTry;
	EndIf;

	If editable = Undefined Or editable.Find("*") <> Undefined Then
		Return NotEditable;
	EndIf;
	
	MetadataObject = Metadata.FindByFullName(ChangingObjectKind);
	For Each AttributeFullName IN MetadataObject.StandardAttributes Do
		NotEditable.Add(AttributeFullName.Name);
	EndDo;
	
	For Each AttributeFullName IN MetadataObject.Attributes Do
		NotEditable.Add(AttributeFullName.Name);
	EndDo;
	
	For Each TabularSection IN MetadataObject.TabularSections Do
		If editable.Find(TabularSection.Name + ".*") <> Undefined Then
			Break;
		EndIf;
		For Each Attribute IN TabularSection.Attributes Do
			NotEditable.Add(TabularSection.Name + "." + Attribute.Name);
		EndDo;
	EndDo;
	
	For Each NameOfEdited IN editable Do
		IndexOf = NotEditable.Find(NameOfEdited);
		If IndexOf = Undefined Then
			Continue;
		EndIf;
		NotEditable.Delete(IndexOf);
	EndDo;
	
	Return NotEditable;
	
EndFunction

&AtServer
Function FilteredAttributes()
	
	If Object.ShowServiceAttributes Then
		Return New Array;
	EndIf;

	MetadataObject = Metadata.FindByFullName(ChangingObjectKind);
	FilteredAttributes = GetEditFilterByType(MetadataObject);
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// Filter by disabled functional options.
	
	ClosedWithFunctionalOptions = New ValueTable;
	ClosedWithFunctionalOptions.Columns.Add("AttributeName",  New TypeDescription("String"));
	
	For Each FODetails IN Metadata.FunctionalOptions Do
		
		If DecomposeStringIntoSubstringsArray(FODetails.Location.FullName(), ".")[0] = "Constant" Then
			ValueFO = GetFunctionalOption(FODetails.Name);
			If TypeOf(ValueFO) = Type("Boolean") AND ValueFO = True Then
				Continue;
			EndIf;
		Else
			// Do not filter attributes included in parameterized functional options.
			Continue;
		EndIf;
		
		For Each OMAttribute IN MetadataObject.Attributes Do
			If FODetails.Content.Contains(OMAttribute) Then
				NewRow = ClosedWithFunctionalOptions.Add();
				NewRow.AttributeName = OMAttribute.Name;
			EndIf;
		EndDo;
		
	EndDo;
	
	ClosedWithFunctionalOptions.GroupBy("AttributeName");
	
	For Each ClosedFO IN ClosedWithFunctionalOptions Do
		FilteredAttributes.Add(ClosedFO.AttributeName);
	EndDo;
	
	Return FilteredAttributes;
	
EndFunction

&AtServer
Procedure FillObjectTableParts(BlockedAttributes, NonEditableAttributes, FilteredAttributes)
	
	MetadataObject = Metadata.FindByFullName(ChangingObjectKind);
	
	// Creating attributes for tabular sections.
	NewFormAttributes = New Array;
	
	TableColumns = AttributeTableColumsDescription();
	
	ObjectTables = New Structure;
	ObjectTabularSections.Clear();
	For Each TabularSectionDescription IN MetadataObject.TabularSections Do
		If Not AccessRight("Edit", TabularSectionDescription) Then
			Continue;
		EndIf;
		// filters of tabular sections
		If NonEditableAttributes.Find(TabularSectionDescription.Name + ".*") <> Undefined Then
			Continue;
		EndIf;
		If FilteredAttributes.Find(TabularSectionDescription.Name + ".*") <> Undefined Then
			Continue;
		EndIf;
		
		AttribitesAvailableForChanging = AttribitesAvailableForChanging(TabularSectionDescription, NonEditableAttributes, FilteredAttributes);
		If AttribitesAvailableForChanging.Count() = 0 Then
			Continue;
		EndIf;
		
		AttributeName = "TabularSection" + TabularSectionDescription.Name;
		ValueTable = New FormAttribute(AttributeName, New TypeDescription("ValueTable"), , TabularSectionDescription.Presentation());
		NewFormAttributes.Add(ValueTable);
		
		For Each ColumnDetails IN TableColumns Do 
			TableAttribute = New FormAttribute(ColumnDetails.Name, ColumnDetails.Type, ValueTable.Name, ColumnDetails.Presentation);
			NewFormAttributes.Add(TableAttribute);
		EndDo;
		
		ObjectTables.Insert(AttributeName, TabularSectionDescription);
		ObjectTabularSections.Add(AttributeName, TabularSectionDescription.Presentation());
	EndDo;
	ChangeAttributes(NewFormAttributes);
	
	For Each ObjectTable IN ObjectTables Do
		AttributeName = ObjectTable.Key;
		PageName = "Page" + AttributeName;
		Page = Items.Add(PageName, Type("FormGroup"), Items.ObjectContent);
		Page.Type = FormGroupType.Page;
		TabularSectionDescription = ObjectTable.Value;
		Page.Title = TabularSectionDescription.Presentation();
		
		// Creating items for tabular sections.
		FormTable = Items.Add(AttributeName, Type("FormTable"), Page);
		FormTable.TitleLocation = FormItemTitleLocation.None;
		FormTable.DataPath = AttributeName;
		FormTable.CommandBarLocation = FormItemCommandBarLabelLocation.None;
		FormTable.Title = TabularSectionDescription.Presentation();
		FormTable.SetAction("BeforeStartChanging", "Attachable_BeforeChangeStart");
		FormTable.ChangeRowOrder = False;
		FormTable.ChangeRowSet = False;
		
		For Each ColumnDetails IN TableColumns Do 
			If ColumnDetails.FieldKind = Undefined Then
				Continue;
			EndIf;
			AttributeName = ColumnDetails.Name;
			ItemName = FormTable.Name + AttributeName;
			TableColumn = Items.Add(ItemName, Type("FormField"), FormTable);
			If ColumnDetails.Picture <> Undefined Then
				TableColumn.TitleLocation = FormItemTitleLocation.None;
				TableColumn.HeaderPicture = ColumnDetails.Picture;
			EndIf;
			TableColumn.DataPath = ObjectTable.Key + "." + AttributeName;
			TableColumn.Type = ColumnDetails.FieldKind;
			TableColumn.EditMode = ColumnEditMode.EnterOnInput;
			TableColumn.ReadOnly = ColumnDetails.ReadOnly;
			If ColumnDetails.Actions <> Undefined Then
				For Each Action IN ColumnDetails.Actions Do
					TableColumn.SetAction(Action.Key, Action.Value);
				EndDo;
			EndIf;
		EndDo;
		
		AttribitesAvailableForChanging = AttribitesAvailableForChanging(TabularSectionDescription, NonEditableAttributes, FilteredAttributes);
		For Each AttributeFullName IN AttribitesAvailableForChanging Do
			Attribute = ThisObject[ObjectTable.Key].Add();
			Attribute.Name = AttributeFullName.Name;
			Attribute.Presentation = ?(IsBlankString(AttributeFullName.Presentation()), AttributeFullName.Name, AttributeFullName.Presentation());
			Attribute.ValidTypes = AttributeFullName.Type;
			Attribute.ChoiceParameterLinks = StringSelectionParametersLinks(AttributeFullName.ChoiceParameterLinks);
			Attribute.ChoiceParameters = StringSelectionParameters(AttributeFullName.ChoiceParameters);
			Attribute.OperationKind = 1;
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Function AttribitesAvailableForChanging(TabularSectionDescription, NonEditableAttributes, FilteredAttributes)
	
	Result = New Array;
	
	For Each AttributeFullName IN TabularSectionDescription.Attributes Do
		If Not AccessRight("Edit", AttributeFullName) Then
			Continue;
		EndIf;
		// Filters of tabular section attributes.
		If NonEditableAttributes.Find(TabularSectionDescription.Name + "." + AttributeFullName.Name) <> Undefined Then
			Continue;
		EndIf;
		If FilteredAttributes.Find(TabularSectionDescription.Name + "." + AttributeFullName.Name) <> Undefined Then
			Continue;
		EndIf;
		
		Result.Add(AttributeFullName);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function AttributeTableColumsDescription()
	
	TableColumns = New ValueTable;
	TableColumns.Columns.Add("Name");
	TableColumns.Columns.Add("Type");
	TableColumns.Columns.Add("Presentation");
	TableColumns.Columns.Add("FieldKind");
	TableColumns.Columns.Add("Actions");
	TableColumns.Columns.Add("ReadOnly", New TypeDescription("Boolean"));
	TableColumns.Columns.Add("Picture");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Name";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Presentation";
	ColumnDetails.Type = New TypeDescription("String");
	ColumnDetails.Presentation = NStr("en = 'Attribute'");
	ColumnDetails.FieldKind = FormFieldType.InputField;
	ColumnDetails.ReadOnly = True;
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Change";
	ColumnDetails.Type = New TypeDescription("Boolean");
	ColumnDetails.FieldKind = FormFieldType.CheckBoxField;
	ColumnDetails.Picture = PictureLib.Change;
	ColumnDetails.Actions = New Structure("OnChange", "Attachable_AtCheckboxChange");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Value";
	ColumnDetails.Type = AllTypes();
	ColumnDetails.Presentation = NStr("en = 'New value'");
	ColumnDetails.FieldKind = FormFieldType.InputField;
	ColumnDetails.Actions = New Structure("OnChange", "Attachable_ValueOnChange");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "ValidTypes";
	ColumnDetails.Type = New TypeDescription("TypeDescription");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "ChoiceParameterLinks";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "ChoiceParameters";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "OperationKind";
	ColumnDetails.Type = New TypeDescription("Number");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Property";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "ChoiceFoldersAndItems";
	ColumnDetails.Type = New TypeDescription("String");
	
	Return TableColumns;
	
EndFunction

&AtServer
Function AllTypes()
	Result = Undefined;
	Attributes = GetAttributes("ObjectAttributes");
	For Each Attribute IN Attributes Do
		If Attribute.Name = "Value" Then
			Result = Attribute.ValueType;
			Break;
		EndIf;
	EndDo;
	Return Result;
EndFunction

&AtClient
Procedure SetLimitsForSelectedTypesAndValueSelectionParameters(TableField)
	If TableField.CurrentData = Undefined Then
		Return;
	EndIf;
	
	InputField = TableField.ChildItems[TableField.Name + "Value"];
	InputField.TypeRestriction = TableField.CurrentData.ValidTypes;
	
	ChoiceParametersArray = New Array;
	
	If Not IsBlankString(TableField.CurrentData.ChoiceParameters) Then
		SetChoiceParametersServer(TableField.CurrentData.ChoiceParameters, ChoiceParametersArray)
	EndIf;
	
	If Not IsBlankString(TableField.CurrentData.ChoiceParameterLinks) Then
		For IndexOf = 1 To StrLineCount(TableField.CurrentData.ChoiceParameterLinks) Do
			ChoiceParametersLinkRow = StrGetLine(TableField.CurrentData.ChoiceParameterLinks, IndexOf);
			SpreadOutRows = DecomposeStringIntoSubstringsArray(ChoiceParametersLinkRow, ";");
			ParameterName = TrimAll(SpreadOutRows[0]);
			
			AttributeName = TrimAll(SpreadOutRows[1]);
			AttributeNameParts = DecomposeStringIntoSubstringsArray(AttributeName, ".", True);
			TabularSectionName = "";
			If AttributeNameParts.Count() > 1 Then
				TabularSectionName = AttributeNameParts[0];
			EndIf;
			AttributeName = AttributeNameParts[AttributeNameParts.Count() - 1];
			
			AttributesTable = ObjectAttributes;
			If Not IsBlankString(TabularSectionName) Then
				AttributesTable = ThisObject["TabularSection" + TabularSectionName];
			EndIf;
			
			FoundStrings = AttributesTable.FindRows(New Structure("OperationKind,Name", 1, AttributeName));
			If FoundStrings.Count() = 1 Then
				Value = FoundStrings[0].Value;
				If ValueIsFilled(Value) Then
					ChoiceParametersArray.Add(New ChoiceParameter(ParameterName, Value));
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	If ValueIsFilled(TableField.CurrentData.Property) Then
		ChoiceParametersArray.Add(New ChoiceParameter("Filter.Owner", TableField.CurrentData.Property));
	EndIf;
	
	InputField.ChoiceParameters = New FixedArray(ChoiceParametersArray);
	
	ChoiceFoldersAndItems = TableField.CurrentData.ChoiceFoldersAndItems;
	
	If ChoiceFoldersAndItems <> "" Then
		If ChoiceFoldersAndItems = "Groups" Then
			InputField.ChoiceFoldersAndItems = FoldersAndItems.Folders;
		ElsIf ChoiceFoldersAndItems = "FoldersAndItems" Then
			InputField.ChoiceFoldersAndItems = FoldersAndItems.FoldersAndItems;
		ElsIf ChoiceFoldersAndItems = "Items" Then
			InputField.ChoiceFoldersAndItems = FoldersAndItems.Items;
		Else
			InputField.ChoiceFoldersAndItems = FoldersAndItems.Auto;
		EndIf;
	Else
		InputField.ChoiceFoldersAndItems = FoldersAndItems.Auto;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateChangingAttributesCounters(Val FormTable = Undefined)
	
	ListOfTables = New Array;
	If FormTable <> Undefined Then
		ListOfTables.Add(FormTable);
	Else
		ListOfTables.Add(Items.ObjectAttributes);
		For Each TabularSection IN ObjectTabularSections Do
			ListOfTables.Add(Items[TabularSection.Value]);
		EndDo;
	EndIf;
	
	For Each FormTable IN ListOfTables Do
		TabularSection = ThisObject[FormTable.Name];
		CountVariable = 0;
		For Each Attribute IN TabularSection Do
			If Attribute.Change Then
				CountVariable = CountVariable + 1;
			EndIf;
		EndDo;
	
		Page = FormTable.Parent;
		Page.Title = FormTable.Title + ?(CountVariable = 0, "", " (" + CountVariable+ ")");
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshElementsVisible()
	If ObjectTabularSections.Count() = 0 Then
		Items.ObjectContent.PagesRepresentation = FormPagesRepresentation.None;
	Else
		Items.ObjectContent.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
	EndIf;
EndProcedure

&AtServer
Procedure FillObjectAttributes(AttributesToLock, NotEditable, FilteredAttributes)
	
	// We open the object manager to receive
	// arrays that are not edited interactively and blocked attributes.
	ObjectManager = ObjectManagerByFullName(ChangingObjectKind);
	MetadataObject = Metadata.FindByFullName(ChangingObjectKind);
	ObjectAttributes.Clear();
	
	AddAttributesToSet(MetadataObject.StandardAttributes,
							NotEditable,
							FilteredAttributes,
							AttributesToLock,
							MetadataObject);
	
	AddAttributesToSet(MetadataObject.Attributes,
							NotEditable,
							FilteredAttributes,
							AttributesToLock,
							MetadataObject);
	
	ObjectAttributes.Sort("Presentation Asc");
	
	UsedAdditAttributes = False;
	UsedAdditInfo = False;
	If SubsystemExists("StandardSubsystems.Properties") Then
		PropertiesManagementModule = CommonModule("PropertiesManagement");
		If PropertiesManagementModule <> Undefined Then
			UsedAdditAttributes = PropertiesManagementModule.UseAdditAttributes(ObjectManager.EmptyRef());
			UsedAdditInfo  = PropertiesManagementModule.UseAdditInfo (ObjectManager.EmptyRef());
			
			If UsedAdditAttributes Or UsedAdditInfo Then
				AddAdditionalDetailsAndInfoToSet();
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure AddAdditionalDetailsAndInfoToSet()
	
	If Not ContextCall Then
		ModulePropertyManagementService = CommonModule("PropertiesManagementService");
		If ModulePropertyManagementService <> Undefined Then
			AddPropertyToAttributeTable(ModulePropertyManagementService.PropertyListForObjectKind(ChangingObjectKind, "AdditionalAttributes"));
			AddPropertyToAttributeTable(ModulePropertyManagementService.PropertyListForObjectKind(ChangingObjectKind, "AdditionalInformation"), False);
		EndIf;
		Return;
	EndIf;
	
	AdditAttributesTable = New ValueTable;
	AdditAttributesTable.Columns.Add("Property",  New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation"));
	AdditAttributesTable.Columns.Add("Description",  New TypeDescription("String"));
	AdditAttributesTable.Columns.Add("ValueType",  New TypeDescription("TypeDescription"));
	
	AdditInfoTable = New ValueTable;
	AdditInfoTable.Columns.Add("Property",  New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation"));
	AdditInfoTable.Columns.Add("Description",  New TypeDescription("String"));
	AdditInfoTable.Columns.Add("ValueType",  New TypeDescription("TypeDescription"));
	
	For Each ObjectData IN SelectedObjects(True).Rows Do
		ObjectToChange = ObjectData.Ref;
		ObjectKindByRef = ObjectKindByRef(ObjectToChange);
		If (ObjectKindByRef = "Catalog" OR ObjectKindByRef = "ChartOfCharacteristicTypes")
		   AND ObjectIsFolder(ObjectToChange) Then
			Continue;
		EndIf;
		
		PropertiesManagementModule = CommonModule("PropertiesManagement");
		AdditionalAttributes = PropertiesManagementModule.GetListOfProperties(ObjectToChange, , False);
		For Each PropertyReference IN AdditionalAttributes Do
			ObjectProperty = PropertyReference.GetObject();
			NewRow = AdditAttributesTable.Add();
			NewRow.Property = ObjectProperty.Ref;;
			NewRow.Description = ObjectProperty.Description;
			NewRow.ValueType = ObjectProperty.ValueType;
		EndDo;
		
		AdditionalInformation = PropertiesManagementModule.GetListOfProperties(ObjectToChange, False);
		For Each PropertyReference IN AdditionalInformation Do
			ObjectProperty = PropertyReference.GetObject();
			NewRow = AdditInfoTable.Add();
			NewRow.Property = ObjectProperty.Ref;;
			NewRow.Description= ObjectProperty.Description;
			NewRow.ValueType = ObjectProperty.ValueType;
		EndDo;
	EndDo;
	
	AdditAttributesTable.GroupBy("Property,Description,ValueType");
	AdditAttributesTable.Sort("Description Asc");
	AdditInfoTable.GroupBy("Property,Description,ValueType");
	AdditInfoTable.Sort("Description Asc");
	
	AddPropertyToAttributeTable(AdditAttributesTable);
	AddPropertyToAttributeTable(AdditInfoTable, False);
	
EndProcedure

&AtServer
Procedure AddPropertyToAttributeTable(TableAdditionalProperties, ThisAdditionalAttribute = True)
	
	For Each TableRow IN TableAdditionalProperties Do
		Attribute = ObjectAttributes.Add();
		Attribute.OperationKind = ?(ThisAdditionalAttribute, 2, 3);
		Attribute.Property		= TableRow.Property;
		Attribute.Presentation = TableRow.Description;
		Attribute.ValidTypes = TableRow.ValueType;
	EndDo;
	
EndProcedure

// Adds operations that may be edited to
// the set (actually attribute and property set).
// It does no include:
//  Non editable - depend on settings of
//  the metadata object filtering - they are defined for metadata objects class.
// Exemptions are included in it.:
//  AttributesToLock - attributes
//  that you can edit only if the user has EditObjectAttributes role.
// Transfered parameters:
// Attributes - metadata object attribute (standard attributes) collection.
// NotEditable, FilteredAttributes - array - filter by attributes.
// AttributesToLock - array - lockable attributes.
//
&AtServer
Procedure AddAttributesToSet(Attributes, NotEditable, FilteredAttributes, AttributesToLock, MetadataObject)
	
	For Each AttributeFullName IN Attributes Do
		If TypeOf(AttributeFullName) = Type("StandardAttributeDescription") Then
			If Not AccessRight("Edit", Metadata.FindByFullName(ChangingObjectKind), , AttributeFullName.Name) Then
				Continue;
			EndIf;
		Else
			If Not AccessRight("Edit", AttributeFullName) Then
				Continue;
			EndIf;
		EndIf;
		
		If NotEditable.Find(AttributeFullName.Name) <> Undefined Then
			Continue;
		EndIf;
		
		If FilteredAttributes.Find(AttributeFullName.Name) <> Undefined Then
			Continue;
		EndIf;
		
		ChoiceFoldersAndItems = "";
		If TypeOf(AttributeFullName) = Type("StandardAttributeDescription") Then
			If AttributeFullName.Name = "Parent" Or AttributeFullName.Name = "Parent" Then
				ChoiceFoldersAndItems = "Groups";
			ElsIf AttributeFullName.Name = "Owner" Or AttributeFullName.Name = "Owner" Then
				If MetadataObject.SubordinationUse = Metadata.ObjectProperties.SubordinationUse.ToElements Then
					ChoiceFoldersAndItems = "Items";
				ElsIf MetadataObject.SubordinationUse = Metadata.ObjectProperties.SubordinationUse.ToGroupsAndItems Then
					ChoiceFoldersAndItems = "FoldersAndItems";
				ElsIf MetadataObject.SubordinationUse = Metadata.ObjectProperties.SubordinationUse.ToGroups Then
					ChoiceFoldersAndItems = "Groups";
				EndIf;
			EndIf;
		Else
			IsReference = False;
			
			For Each Type IN AttributeFullName.Type.Types() Do
				If IsReference(Type) Then
					IsReference = True;
					Break;
				EndIf;
			EndDo;
			
			If IsReference Then
				If AttributeFullName.ChoiceFoldersAndItems = FoldersAndItemsUse.Folders Then
					ChoiceFoldersAndItems = "Groups";
				ElsIf AttributeFullName.ChoiceFoldersAndItems = FoldersAndItemsUse.FoldersAndItems Then
					ChoiceFoldersAndItems = "FoldersAndItems";
				ElsIf AttributeFullName.ChoiceFoldersAndItems = FoldersAndItemsUse.Items Then
					ChoiceFoldersAndItems = "Items";
				EndIf;
			EndIf;
		EndIf;
		
		ChoiceParametersString = StringSelectionParameters(AttributeFullName.ChoiceParameters);
		ChoiceParameterLinksString = StringSelectionParametersLinks(AttributeFullName.ChoiceParameterLinks);
		
		NewOperation = ObjectAttributes.Add();
		NewOperation.Name = AttributeFullName.Name;
		NewOperation.Presentation = AttributeFullName.Presentation();
		NewOperation.OperationKind = 1; // Attribute
		NewOperation.ValidTypes = AttributeFullName.Type;
		NewOperation.ChoiceParameters = ChoiceParametersString;
		NewOperation.ChoiceParameterLinks = ChoiceParameterLinksString;
		NewOperation.ChoiceFoldersAndItems = ChoiceFoldersAndItems;
		
		If AttributesToLock.Find(AttributeFullName.Name) <> Undefined Then
			NewOperation.BlockedAttribute = True;
		EndIf;
		
	EndDo;
	
EndProcedure

// Receives the array of attributes
// failed to be edited at the configuration level.
//
&AtServer
Function GetEditFilterByType(MetadataObject)
	
	DataProcessorObject = FormAttributeToValue("Object");
	FilterXML = DataProcessorObject.GetTemplate("AttributesFilter").GetText();
	
	FilterTable = ReadXMLToTable(FilterXML).Data;
	
	// Attributes blocked for any type of metadata objects.
	CommonFilter = FilterTable.FindRows(New Structure("ObjectType", "*"));
	
	// Attributes blocked for specified type of metadata objects.
	FilterByOMType = FilterTable.FindRows(
							New Structure("ObjectType", 
							BaseTypeNameByMetadataObject(MetadataObject)));
	
	FilteredAttributes = New Array;
	
	For Each StringDetails IN CommonFilter Do
		FilteredAttributes.Add(StringDetails.Attribute);
	EndDo;
	
	For Each StringDetails IN FilterByOMType Do
		FilteredAttributes.Add(StringDetails.Attribute);
	EndDo;
	
	PrefixRemovedAttributes = "Delete";
	For Each Attribute IN MetadataObject.Attributes Do
		If Lower(Left(Attribute.Name, StrLen(PrefixRemovedAttributes))) = Lower(PrefixRemovedAttributes) Then
			FilteredAttributes.Add(Attribute.Name);
		EndIf;
	EndDo;
	For Each TabularSection IN MetadataObject.TabularSections Do
		If Lower(Left(TabularSection.Name, StrLen(PrefixRemovedAttributes))) = Lower(PrefixRemovedAttributes) Then
			FilteredAttributes.Add(TabularSection.Name + ".*");
		Else
			For Each Attribute IN TabularSection.Attributes Do
				If Lower(Left(Attribute.Name, StrLen(PrefixRemovedAttributes))) = Lower(PrefixRemovedAttributes) Then
					FilteredAttributes.Add(TabularSection.Name + "." + Attribute.Name);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Return FilteredAttributes;
	
EndFunction

&AtServer
Function FilterItemsWithoutHierarchy(Val FilterItems)
	Result = New Array;
	For Each FilterItem IN FilterItems Do
		If TypeOf(FilterItem) = Type("DataCompositionFilterItemGroup") Then
			SubordinateFilters = FilterItemsWithoutHierarchy(FilterItem.Items);
			For Each SubordinatedFilter IN SubordinateFilters Do
				Result.Add(SubordinatedFilter);
			EndDo;
		Else
			Result.Add(FilterItem);
		EndIf;
	EndDo;
	Return Result;
EndFunction

&AtServer
Procedure GenerateConfiguredChangesExplanation()
	
	FilterByStrings = False;
	For Each FilterItem IN FilterItemsWithoutHierarchy(SettingsComposer.Settings.Filter.Items) Do
		If Not FilterItem.Use Then
			Continue;
		EndIf;
		For Each TabularSection IN ObjectTabularSections Do
			TabularSectionName = Mid(TabularSection.Value, StrLen("TabularSection") + 1);
			If Left(FilterItem.LeftValue, StrLen(TabularSectionName)) = TabularSectionName Then
				FilterByStrings = True;
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	ChangeableTableParts = New Map;
	For Each TabularSection IN ObjectTabularSections Do
		ChangeableAttributes = New Array;
		For Each Attribute IN ThisObject[TabularSection.Value] Do
			If Attribute.Change Then
				ChangeableAttributes.Add(Attribute.Presentation);
			EndIf;
		EndDo;
		If ChangeableAttributes.Count() > 0 Then 
			ChangeableTableParts.Insert(TabularSection.Presentation, ChangeableAttributes);
		EndIf;
	EndDo;
	
	ChangeableAttributes = New Array;
	For Each Attribute IN ObjectAttributes Do
		If Attribute.Change Then
			ChangeableAttributes.Add(Attribute.Presentation);
		EndIf;
	EndDo;
	
	ThereAreSelectedObjects = SelectedObjectsCount() > 0;
	
	Explanation = "";
	If ChangeableAttributes.Count() > 3 Then
		Explanation = "(" + ChangeableAttributes.Count() +")";
	Else
		For Each Attribute IN ChangeableAttributes Do
			If Not IsBlankString(Explanation) Then
				Explanation = Explanation + ", ";
			EndIf;
			Explanation = Explanation + """" + Attribute + """";
		EndDo;
	EndIf;
	
	If ChangeableAttributes.Count() = 1 Then
		Explanation = NStr("en = 'Attribute'") + " " + Explanation;
	ElsIf ChangeableAttributes.Count() > 1 Then
		Explanation = NStr("en = 'attributes'") + " " + Explanation;
	EndIf;
	
	If Not IsBlankString(Explanation) Then
		Explanation = Explanation + " " + NStr("en = 'in selected items'");
	EndIf;
	
	For Each TabularSection IN ChangeableTableParts Do
		ChangeableAttributes = TabularSection.Value;
		If ChangeableAttributes.Count() > 3 Then
			If Not IsBlankString(Explanation) Then
				Explanation = Explanation + ", ";
			EndIf;
			Explanation = Explanation + PlaceParametersIntoString(
				NStr("en = 'attributes (%1)'"), ChangeableAttributes.Count());
		Else
			For Each Attribute IN ChangeableAttributes Do
				If Not IsBlankString(Explanation) Then
					Explanation = Explanation + ", ";
				EndIf;
				If ChangeableAttributes.Find(Attribute) = 0 Then
					If ChangeableAttributes.Count() = 1 Then
						Explanation = Explanation + NStr("en = 'Attribute'") + " ";
					ElsIf ChangeableAttributes.Count() > 1 Then
						Explanation =  Explanation + NStr("en = 'attributes'") + " ";
					EndIf;
				EndIf;
				Explanation = Explanation + """" + Attribute + """";
			EndDo;
		EndIf;
		Explanation = Explanation + " " 
			+ PlaceParametersIntoString(NStr("en = 'in tabular section ""%1""'"), TabularSection.Key);
	EndDo;
	
	If Not IsBlankString(Explanation) Then
		If ChangeableTableParts.Count() > 0 Then
			If FilterByStrings Then 
				Explanation = Explanation + " " + NStr("en = 'in selected item strings answering filter conditions'")
			Else
				Explanation = Explanation + " " + NStr("en = 'for all strings of selected items'")
			EndIf;
		EndIf;
	EndIf;
	
	If ThereAreSelectedObjects Then
		If Not IsBlankString(Explanation) Then
			Explanation = NStr("en = 'Change'") + " " + Explanation + ".";
		Else
			Explanation = NStr("en = 'Rewrite the selected items.'");
		EndIf;
	Else
		Explanation = NStr("en = 'Items with the attributes to be changed are not selected.'");
	EndIf;
	
	Items.SettingChangesExplanation.Title = Explanation;
EndProcedure

&AtServer
Procedure UpdateLabelSelectedCount()
	ThereAreErrorsInSelection = False;
	If ThereAreCustomizedFilters() Then
		ErrorMessageText = "";
		SelectedObjectsCount = SelectedObjectsCount(True, , ErrorMessageText);
		If IsBlankString(ErrorMessageText) Then
			LabelText = PlaceParametersIntoString(
				NStr("en = 'Chosen items: %1'"), SelectedObjectsCount);
		Else
			ThereAreErrorsInSelection = True;
			LabelText = PlaceParametersIntoString(
				NStr("en = 'Items are not selected. %1'"), ErrorMessageText);
		EndIf;
	Else
		LabelText = NStr("en = 'Change all items'");
	EndIf;
	
	Items.FilterSettings.Title = LabelText;
	Items.FilterSettings.Hyperlink = Not ThereAreErrorsInSelection;
	
EndProcedure

&AtServer
Procedure FillSubmenuPreviouslyModifiedAttributes()
	
	CommandsPlacementPlace = Items.PreviouslyModifiedAttributes;
	
	DeletedItems = New Array;
	For Each Setting IN CommandsPlacementPlace.ChildItems Do
		If Setting.Name = "EndCap" Then
			Continue;
		EndIf;
		DeletedItems.Add(Setting);
	EndDo;
	
	For Each Setting IN DeletedItems Do
		Commands.Delete(Commands[Setting.Name]);
		Items.Delete(Setting);
	EndDo;
	
	For Each Setting IN OperationsHistoryList Do
		NumberCommands = OperationsHistoryList.IndexOf(Setting);
		CommandName = CommandsPlacementPlace.Name + "ConfigurationChanges" + NumberCommands;
		
		FormCommand = Commands.Add(CommandName);
		FormCommand.Action = "Attachable_ConfigureSettings";
		FormCommand.Title = Setting.Presentation;
		FormCommand.ModifiesStoredData = False;
		
		NewItem = Items.Add(CommandName, Type("FormButton"), CommandsPlacementPlace);
		NewItem.Type = FormButtonType.CommandBarButton;
		NewItem.CommandName = CommandName;
	EndDo;
	
	Items.EndCap.Visible = OperationsHistoryList.Count() = 0;
	
EndProcedure

&AtClient
Procedure ConfigureChangeSetting(Val Setting)
	
	ResetChangeSettings();
	
	IsBlocked = False;
	
	// To ensure backward compatibility with settings stored in SSL 2.1.
	If TypeOf(Setting) <> Type("Structure") Then
		Setting = New Structure("Attributes,TableParts", Setting, New Structure);
	EndIf;
	
	For Each VariableAttribute IN Setting.Attributes Do
		SearchStructure = New Structure;
		SearchStructure.Insert("OperationKind", VariableAttribute.OperationKind);
		If VariableAttribute.OperationKind = 1 Then // object attribute
			SearchStructure.Insert("Name", VariableAttribute.AttributeName);
		Else
			SearchStructure.Insert("Property", VariableAttribute.Property);
		EndIf;
		
		FoundStrings = ObjectAttributes.FindRows(SearchStructure);
		If FoundStrings.Count() > 0 Then
			If FoundStrings[0].BlockedAttribute  Then
				IsBlocked = True;
				Continue;
			EndIf;
			FoundStrings[0].Value = VariableAttribute.Value;
			FoundStrings[0].Change = True;
		EndIf;
	EndDo;
	
	For Each TabularSection IN Setting.TabularSections Do
		For Each VariableAttribute IN TabularSection.Value Do
			SearchStructure = New Structure;
			SearchStructure.Insert("Name", VariableAttribute.Name);
			If Items.Find("TabularSection" + TabularSection.Key) <> Undefined Then
				FoundStrings = ThisObject["TabularSection" + TabularSection.Key].FindRows(SearchStructure);
				If FoundStrings.Count() > 0 Then
					FoundStrings[0].Value = VariableAttribute.Value;
					FoundStrings[0].Change = True;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	If IsBlocked Then
		ShowMessageBox(, NStr("en = 'Some attributes are blocked for modifications, changes not set'"));
	EndIf;
	
	UpdateChangingAttributesCounters();
EndProcedure


&AtServer
Function StringSelectionParameters(ChoiceParameters)
	Result = "";
	
	For Each DescriptionOfChoiceParameter IN ChoiceParameters Do
		CurrentCPString = "[FilterField];[StringType];[ValueString]";
		ValueType = TypeOf(DescriptionOfChoiceParameter.Value);
		
		If ValueType = Type("FixedArray") Then
			TypePresentationString = "FixedArray";
			ValueString = "";
			
			For Each Item IN DescriptionOfChoiceParameter.Value Do
				ValueStringTemplate = "[Type]*[Value]";
				ValueStringTemplate = StrReplace(ValueStringTemplate, "[Type]", TypePresentationString(TypeOf(Item)));
				ValueStringTemplate = StrReplace(ValueStringTemplate, "[Value]", XMLString(Item));
				ValueString = ValueString + ?(IsBlankString(ValueString), "", "#") + ValueStringTemplate;
			EndDo;
		Else
			TypePresentationString = TypePresentationString(ValueType);
			ValueString = XMLString(DescriptionOfChoiceParameter.Value);
		EndIf;
		
		If Not IsBlankString(ValueString) Then
			CurrentCPString = StrReplace(CurrentCPString, "[FilterField]", DescriptionOfChoiceParameter.Name);
			CurrentCPString = StrReplace(CurrentCPString, "[StringType]", TypePresentationString);
			CurrentCPString = StrReplace(CurrentCPString, "[ValueString]", ValueString);
			
			Result = Result + CurrentCPString + Chars.LF;
		EndIf;
	EndDo;
	
	Result = Left(Result, StrLen(Result)-1);
	Return Result;
EndFunction

&AtServer
Function StringSelectionParametersLinks(ChoiceParameterLinks)
	Result = "";
	
	For Each DetailsChoiceParameterLinks IN ChoiceParameterLinks Do
		CurrentCPCString = "[ParameterName];[AttributeName]";
		CurrentCPCString = StrReplace(CurrentCPCString, "[ParameterName]", DetailsChoiceParameterLinks.Name);
		CurrentCPCString = StrReplace(CurrentCPCString, "[AttributeName]", DetailsChoiceParameterLinks.DataPath);
		Result = Result + CurrentCPCString + Chars.LF;
	EndDo;
	
	Result = Left(Result, StrLen(Result)-1);
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedure and function of basic functionality to ensure independence.

// Saves the setting in common settings storage.
// 
// Parameters:
//   Correspond to
// CommonSettingsStorageSave.Save method, for more details - see StorageSave procedure parameters().
// 
&AtServerNoContext
Procedure CommonSettingsStorageSave(ObjectKey, SettingsKey, Value,
	SettingsDescription = Undefined, UserName = Undefined, 
	NeedToUpdateReusedValues = False)
	
	StorageSave(
		CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		Value,
		SettingsDescription,
		UserName,
		NeedToUpdateReusedValues);
	
EndProcedure

// Imports the setting from common settings storage.
//
// Parameters:
//   Correspond
//   to CommonSettingsStorage.Import method, details - see StorageImport function parameters().
//
&AtServerNoContext
Function CommonSettingsStorageImport(ObjectKey, SettingsKey, DefaultValue = Undefined, 
	SettingsDescription = Undefined, UserName = Undefined)
	
	Return StorageImport(
		CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDescription,
		UserName);
	
EndFunction

&AtServerNoContext
Procedure StorageSave(StorageManager, ObjectKey, SettingsKey, Value,
	SettingsDescription, UserName, NeedToUpdateReusedValues)
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	StorageManager.Save(ObjectKey, SettingsKey(SettingsKey), Value, SettingsDescription, UserName);
	
	If NeedToUpdateReusedValues Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

&AtServerNoContext
Function StorageImport(StorageManager, ObjectKey, SettingsKey, DefaultValue,
	SettingsDescription, UserName)
	
	Result = Undefined;
	
	If AccessRight("SaveUserData", Metadata) Then
		Result = StorageManager.Load(ObjectKey, SettingsKey(SettingsKey), SettingsDescription, UserName);
	EndIf;
	
	If (Result = Undefined) AND (DefaultValue <> Undefined) Then
		Result = DefaultValue;
	EndIf;

	Return Result;
	
EndFunction

// Returns settings key string not exceeding the allowed length.
// Checks the string length at login and in case it exceeds 128, converts its end to
// the short version using MD5 algorithm, so the string length becomes equal to 128 characters.
// If the source string is less than 128 characters, it is returned as it is.
//
// Parameters:
//  String - String - String of arbitrary length.
//
&AtServerNoContext
Function SettingsKey(Val String)
	Result = String;
	If StrLen(String) > 128 Then // Key of more than 128 characters will cause an exception when accessing the settings storage.
		Result = Left(String, 96);
		DataHashing = New DataHashing(HashFunction.MD5);
		DataHashing.Append(Mid(String, 97));
		Result = Result + StrReplace(DataHashing.HashSum, " ", "");
	EndIf;
	Return Result;
EndFunction

// Returns the object manager by a full metadata object name.
//
// Points of business processes are not processed.
//
// Parameters:
//  DescriptionFull    - String, metadata object
//                 full name, for example, "Catalog.Companies".
//
// Returns:
//  CatalogManager, DocumentManager, ...
// 
&AtServerNoContext
Function ObjectManagerByFullName(DescriptionFull)
	Var MOClass, MOName, Manager;
	
	NameParts = DecomposeStringIntoSubstringsArray(DescriptionFull, ".");
	
	If NameParts.Count() = 2 Then
		MOClass = NameParts[0];
		MOName  = NameParts[1];
	EndIf;
	
	If      Upper(MOClass) = "EXCHANGEPLAN" Then
		Manager = ExchangePlans;
		
	ElsIf Upper(MOClass) = "CATALOG" Then
		Manager = Catalogs;
		
	ElsIf Upper(MOClass) = "DOCUMENT" Then
		Manager = Documents;
		
	ElsIf Upper(MOClass) = "DOCUMENTJOURNAL" Then
		Manager = DocumentJournals;
		
	ElsIf Upper(MOClass) = "ENUM" Then
		Manager = Enums;
		
	ElsIf Upper(MOClass) = "REPORT" Then
		Manager = Reports;
		
	ElsIf Upper(MOClass) = "DATAPROCESSOR" Then
		Manager = DataProcessors;
		
	ElsIf Upper(MOClass) = "CHARTOFCHARACTERISTICTYPES" Then
		Manager = ChartsOfCharacteristicTypes;
		
	ElsIf Upper(MOClass) = "CHARTOFACCOUNTS" Then
		Manager = ChartsOfAccounts;
		
	ElsIf Upper(MOClass) = "CHARTOFCALCULATIONTYPES" Then
		Manager = ChartsOfCalculationTypes;
		
	ElsIf Upper(MOClass) = "INFORMATIONREGISTER" Then
		Manager = InformationRegisters;
		
	ElsIf Upper(MOClass) = "ACCUMULATIONREGISTER" Then
		Manager = AccumulationRegisters;
		
	ElsIf Upper(MOClass) = "ACCOUNTINGREGISTER" Then
		Manager = AccountingRegisters;
		
	ElsIf Upper(MOClass) = "CALCULATIONREGISTER" Then
		If NameParts.Count() = 2 Then
			// Calculation register
			Manager = CalculationRegisters;
		Else
			ClassSubordinateOM = NameParts[2];
			NameOfSlave = NameParts[3];
			If Upper(ClassSubordinateOM) = "Recalculation" Then
				// Recalculation
				Manager = CalculationRegisters[MOName].Recalculations;
			Else
				Raise PlaceParametersIntoString(
					NStr("en = 'Unknown type of metadata object ""%1""'"), DescriptionFull);
			EndIf;
		EndIf;
		
	ElsIf Upper(MOClass) = "BUSINESSPROCESS" Then
		Manager = BusinessProcesses;
		
	ElsIf Upper(MOClass) = "TASK" Then
		Manager = Tasks;
		
	ElsIf Upper(MOClass) = "Constant" Then
		Manager = Constants;
		
	ElsIf Upper(MOClass) = "Sequence" Then
		Manager = Sequences;
	EndIf;
	
	If Manager <> Undefined Then
		Try
			Return Manager[MOName];
		Except
			Manager = Undefined;
		EndTry;
	EndIf;
	
	Raise PlaceParametersIntoString(
		NStr("en = 'Unknown type of metadata object ""%1""'"), DescriptionFull);
	
EndFunction

// It splits a line into several lines according to a delimiter. Delimiter may have any length.
//
// Parameters:
//  String                 - String - Text with delimiters;
//  Delimiter            - String - Delimiter of text lines, minimum 1 symbol;
//  SkipBlankStrings - Boolean - Flag of necessity to show empty lines in the result.
//    If the parameter is not specified, the function works in the mode of compatibility with its previous version:
//     - for delimiter-space empty lines are not included in the result, for other
//       delimiters empty lines are included in the result.
//     E if Line parameter does not contain significant characters or doesn't contain any symbol (empty line),
//       then for delimiter-space the function result is an array containing one value ""
//       (empty line) and for other delimiters the function result is the empty array.
//
//
// Returns:
//  Array - array of rows.
//
// Examples:
//  DecomposeStringIntoSubstringsArray(",one,,two,", ",") - it will return the array of 5 elements three of which  - empty
//  lines;
//  DecomposeStringIntoSubstringsArray(",one,,two,", ",", True) - it will return an array of two items;
//  DecomposeStringIntoSubstringArray("one two ", " ") - it will return an array of two items;
//  DecomposeStringIntoSubstringArray("") - It returns an empty array;
//  DecomposeStringIntoSubstringsArray("",,False) - It returns an array with one element "" (empty line);
//  DecomposeStringIntoSubstringsArray("", " ") - It returns an array with one element "" (empty line);
//
&AtClientAtServerNoContext
Function DecomposeStringIntoSubstringsArray(Val String, Val Delimiter = ",", Val SkipBlankStrings = Undefined)
	
	Result = New Array;
	
	// To ensure backward compatibility.
	If SkipBlankStrings = Undefined Then
		SkipBlankStrings = ?(Delimiter = " ", True, False);
		If IsBlankString(String) Then 
			If Delimiter = " " Then
				Result.Add("");
			EndIf;
			Return Result;
		EndIf;
	EndIf;
	//
	
	Position = Find(String, Delimiter);
	While Position > 0 Do
		Substring = Left(String, Position - 1);
		If Not SkipBlankStrings Or Not IsBlankString(Substring) Then
			Result.Add(Substring);
		EndIf;
		String = Mid(String, Position + StrLen(Delimiter));
		Position = Find(String, Delimiter);
	EndDo;
	
	If Not SkipBlankStrings Or Not IsBlankString(String) Then
		Result.Add(String);
	EndIf;
	
	Return Result;
	
EndFunction 

&AtClientAtServerNoContext
// You shall use ArrayToString.
// Merges array strings to a string with delimiters.
//
// Parameters:
//  Array      - Array - array of strings to be merged into one string;
//  Delimiter - String - any set of characters that will be used as delimeters.
//
// Returns:
//  String - String with delimiters.
// 
Function RowFromArraySubrows(Array, Delimiter = ",", ReduceNonPrintableChars = False)
	
	Result = "";
	
	For IndexOf = 0 To Array.UBound() Do
		Substring = Array[IndexOf];
		
		If ReduceNonPrintableChars Then
			Substring = TrimAll(Substring);
		EndIf;
		
		If TypeOf(Substring) <> Type("String") Then
			Substring = String(Substring);
		EndIf;
		
		If IndexOf > 0 Then
			Result = Result + Delimiter;
		EndIf;
		
		Result = Result + Substring;
	EndDo;
	
	Return Result;
	
EndFunction

// It substitutes the parameters into the string. 
// Parameters in the line are specified as %<parameter number>. Parameter numbering starts with one.
//
// Parameters:
//  LookupString  - String - String template with parameters (inclusions of "%ParameterName" type);
//  Parameter<n>        - String - substituted parameter.
//
// Returns:
//  String   - text string with substituted parameters.
//
// Example:
//  PlaceParametersIntoString(NStr("en='%1 went to %2'"), "John", "Zoo") = "John went to the Zoo".
//
&AtClientAtServerNoContext
Function PlaceParametersIntoString(Val LookupString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	UseAlternativeAlgorithm = 
		Find(Parameter1, "%")
		Or Find(Parameter2, "%")
		Or Find(Parameter3, "%");
		
	If UseAlternativeAlgorithm Then
		LookupString = SubstituteParametersInStringAlternateAlgorithm(LookupString, Parameter1,
			Parameter2, Parameter3);
	Else
		LookupString = StrReplace(LookupString, "%1", Parameter1);
		LookupString = StrReplace(LookupString, "%2", Parameter2);
		LookupString = StrReplace(LookupString, "%3", Parameter3);
	EndIf;
	
	Return LookupString;
EndFunction

// It inserts parameters into the string taking into account that you can use substitution words %1, %2 etc. in  parameters
&AtClientAtServerNoContext
Function SubstituteParametersInStringAlternateAlgorithm(Val LookupString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	Result = "";
	Position = Find(LookupString, "%");
	While Position > 0 Do 
		Result = Result + Left(LookupString, Position - 1);
		CharAfterPercent = Mid(LookupString, Position + 1, 1);
		SetParameter = "";
		If CharAfterPercent = "1" Then
			SetParameter =  Parameter1;
		ElsIf CharAfterPercent = "2" Then
			SetParameter =  Parameter2;
		ElsIf CharAfterPercent = "3" Then
			SetParameter =  Parameter3;
		EndIf;
		If SetParameter = "" Then
			Result = Result + "%";
			LookupString = Mid(LookupString, Position + 1);
		Else
			Result = Result + SetParameter;
			LookupString = Mid(LookupString, Position + 2);
		EndIf;
		Position = Find(LookupString, "%");
	EndDo;
	Result = Result + LookupString;
	
	Return Result;
EndFunction

// Function ObjectKindByRef returns the type name
// for the metadata objects by the link to the object.
//
// Points of business processes are not processed.
//
// Parameters:
//  Ref       - ref to object, - catalog item, document, ...
//
// Returns:
//  String       - metadata object kind name, for example, "Catalog" "Document" ...
// 
&AtServerNoContext
Function ObjectKindByRef(Ref)
	
	Return ObjectKindByKind(TypeOf(Ref));
	
EndFunction 

// Function returns the metadata object kind name based on the object type.
//
// Points of business processes are not processed.
//
// Parameters:
//  Type       - Type of applied object defined in configuration.
//
// Returns:
//  String       - metadata object kind name, for example, "Catalog" "Document" ...
// 
&AtServerNoContext
Function ObjectKindByKind(Type)
	
	If Catalogs.AllRefsType().ContainsType(Type) Then
		Return "Catalog";
	
	ElsIf Documents.AllRefsType().ContainsType(Type) Then
		Return "Document";
	
	ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
		Return "BusinessProcess";
	
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCharacteristicTypes";
	
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
		Return "ChartOfAccounts";
	
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCalculationTypes";
	
	ElsIf Tasks.AllRefsType().ContainsType(Type) Then
		Return "Task";
	
	ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
		Return "ExchangePlan";
	
	ElsIf Enums.AllRefsType().ContainsType(Type) Then
		Return "Enum";
	
	Else
		Raise PlaceParametersIntoString(
			NStr("en='InvalidValueTypeParameter%1'"), String(Type));
	
	EndIf;
	
EndFunction 

// Checks whether the object is a group of items.
//
// Parameters:
//  Object       - Object, Reference, FormDataStructure by Object type.
//
// Returns:
//  Boolean.
//
&AtServerNoContext
Function ObjectIsFolder(Object)
	
	If ReferenceTypeValue(Object) Then
		Ref = Object;
	Else
		Ref = Object.Ref;
	EndIf;
	
	ObjectMetadata = Ref.Metadata();
	
	If ThisIsCatalog(ObjectMetadata) Then
		
		If Not ObjectMetadata.Hierarchical
		 OR ObjectMetadata.HierarchyType
		     <> Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
			
			Return False;
		EndIf;
		
	ElsIf Not ThisIsChartOfCharacteristicTypes(ObjectMetadata) Then
		Return False;
		
	ElsIf Not ObjectMetadata.Hierarchical Then
		Return False;
	EndIf;
	
	If Ref <> Object Then
		Return Object.IsFolder;
	EndIf;
	
	Return ObjectAttributeValue(Ref, "IsFolder");
	
EndFunction

// Defines metadata object belonging to Catalog common type.
// 
// Parameters:
//  MetadataObject - metadata object for which it is necessary to determine the beloning to the specified type.
// 
//  Returns:
//   Boolean.
//
&AtServerNoContext
Function ThisIsCatalog(MetadataObject)
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameCatalogs();
	
EndFunction

// Checks if the type has a reference data type.
//
&AtServerNoContext
Function IsReference(Type)
	
	Return Type <> Type("Undefined") 
		AND (Catalogs.AllRefsType().ContainsType(Type)
		OR Documents.AllRefsType().ContainsType(Type)
		OR Enums.AllRefsType().ContainsType(Type)
		OR ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type)
		OR ChartsOfAccounts.AllRefsType().ContainsType(Type)
		OR ChartsOfCalculationTypes.AllRefsType().ContainsType(Type)
		OR BusinessProcesses.AllRefsType().ContainsType(Type)
		OR BusinessProcesses.RoutePointsAllRefsType().ContainsType(Type)
		OR Tasks.AllRefsType().ContainsType(Type)
		OR ExchangePlans.AllRefsType().ContainsType(Type));
	
EndFunction

// Verify that the value has a reference data type.
//
// Parameters:
//  Value       - ref to object, - catalog item, document, ...
//
// Returns:
//  Boolean       - True if value type is reference.
//
&AtServerNoContext
Function ReferenceTypeValue(Value)
	
	If Value = Undefined Then
		Return False;
	EndIf;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Documents.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Enums.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCharacteristicTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfAccounts.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCalculationTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.RoutePointsAllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Tasks.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ExchangePlans.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Defines a metadata object belonging to Characteristic Kinds Plan common type.
// 
// Parameters:
//  MetadataObject - metadata object for which it is necessary to determine the beloning to the specified type.
// 
//  Returns:
//   Boolean.
//
&AtServerNoContext
Function ThisIsChartOfCharacteristicTypes(MetadataObject)
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = TypeNameChartsOfCharacteristicTypes();
	
EndFunction

// Returns the name of basic type based on the transferred value of metadata object.
// 
// Parameters:
//  MetadataObject - metadata object for which it is necessary to define the base type.
// 
// Returns:
//  String - name of basic type based on the transferred value of metadata object.
//
&AtServerNoContext
Function BaseTypeNameByMetadataObject(MetadataObject)
	
	If Metadata.Documents.Contains(MetadataObject) Then
		Return TypeNameDocuments();
		
	ElsIf Metadata.Catalogs.Contains(MetadataObject) Then
		Return TypeNameCatalogs();
		
	ElsIf Metadata.Enums.Contains(MetadataObject) Then
		Return TypeNameEnums();
		
	ElsIf Metadata.InformationRegisters.Contains(MetadataObject) Then
		Return TypeNameInformationRegisters();
		
	ElsIf Metadata.AccumulationRegisters.Contains(MetadataObject) Then
		Return TypeNameAccumulationRegisters();
		
	ElsIf Metadata.AccountingRegisters.Contains(MetadataObject) Then
		Return TypeNameOfAccountingRegisters();
		
	ElsIf Metadata.CalculationRegisters.Contains(MetadataObject) Then
		Return NameKindCalculationRegisters();
		
	ElsIf Metadata.ExchangePlans.Contains(MetadataObject) Then
		Return TypeNameExchangePlans();
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject) Then
		Return TypeNameChartsOfCharacteristicTypes();
		
	ElsIf Metadata.BusinessProcesses.Contains(MetadataObject) Then
		Return BusinessProcessTypeName();
		
	ElsIf Metadata.Tasks.Contains(MetadataObject) Then
		Return TypeNameTasks();
		
	ElsIf Metadata.ChartsOfAccounts.Contains(MetadataObject) Then
		Return TypeNameChartsOfAccounts();
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(MetadataObject) Then
		Return TypeNameChartsOfCalculationTypes();
		
	ElsIf Metadata.Constants.Contains(MetadataObject) Then
		Return TypeNameConstants();
		
	ElsIf Metadata.DocumentJournals.Contains(MetadataObject) Then
		Return TypeNameDocumentJournals();
		
	ElsIf Metadata.Sequences.Contains(MetadataObject) Then
		Return TypeNameSequences();
		
	ElsIf Metadata.ScheduledJobs.Contains(MetadataObject) Then
		Return TypeNameScheduledJobs();
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction

// Returns the value for Data Registers common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameInformationRegisters()
	
	Return "InformationRegisters";
	
EndFunction

// Returns the value for Accumulation Registers common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameAccumulationRegisters()
	
	Return "AccumulationRegisters";
	
EndFunction

// Returns the value for Accounting Registers common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameOfAccountingRegisters()
	
	Return "AccountingRegisters";
	
EndFunction

// Returns the value for Calculation Registers common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function NameKindCalculationRegisters()
	
	Return "CalculationRegisters";
	
EndFunction

// Return a value to identify common type "Documents".
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameDocuments()
	
	Return "Documents";
	
EndFunction

// Returns the value for Catalogs common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameCatalogs()
	
	Return "Catalogs";
	
EndFunction

// Returns the value for Transfers common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameEnums()
	
	Return "Enums";
	
EndFunction

// Returns the value for ExchangePlans common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameExchangePlans()
	
	Return "ExchangePlans";
	
EndFunction

// Returns the value for Characteristics Kinds Plans common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameChartsOfCharacteristicTypes()
	
	Return "ChartsOfCharacteristicTypes";
	
EndFunction

// Returns the value for Business Processes common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function BusinessProcessTypeName()
	
	Return "BusinessProcesses";
	
EndFunction

// Returns a value for the Tasks common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameTasks()
	
	Return "Tasks";
	
EndFunction

// Returns the value for Charts of Accounts common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameChartsOfAccounts()
	
	Return "ChartsOfAccounts";
	
EndFunction

// Returns the value for Calculation Kind Plans common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameChartsOfCalculationTypes()
	
	Return "ChartsOfCalculationTypes";
	
EndFunction

// Returns the value for Constants common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameConstants()
	
	Return "Constants";
	
EndFunction

// Returns the value for Document Journals common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameDocumentJournals()
	
	Return "DocumentJournals";
	
EndFunction

// Returns the value for Sequences common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameSequences()
	
	Return "Sequences";
	
EndFunction

// Returns a value for the ScheduledJobs common type identification.
//
// Returns:
//  Row.
//
&AtServerNoContext
Function TypeNameScheduledJobs()
	
	Return "ScheduledJobs";
	
EndFunction

// It returns a structure containing attribute values read
// from the infobase by the object link.
// 
//  If there is no access to one of the attributes, access right exception will occur.
//  If it is required to read the attribute
//  regardless of the current user rights, then you should use preliminary transition to the privileged mode.
// 
// Parameters:
//  Ref    - Object ref - catalog item, document, ...
//
//  Attributes - String - attribute names listed comma separated in
//              the format of structure property requirements.
//              For example, "Code, Name, Parent".
//            - Structure, FixedStructure - field alias name
//              is transferred as a key for the returned structure with
//              the result and actual field name in the table is transferred (optionally) as the value.
//              If the value is not specified, then the field name is taken from the key.
//            - Array, FixedArray - attribute names in the
//              format of requirements to the structure properties.
//
// Returns:
//  Structure - includes names (keys) and values of the requested attribute.
//              If a row of the claimed attributes is empty, then an empty structure returns.
//
&AtServerNoContext
Function ObjectAttributesValues(Ref, Val Attributes)
	
	If TypeOf(Attributes) = Type("String") Then
		If IsBlankString(Attributes) Then
			Return New Structure;
		EndIf;
		Attributes = DecomposeStringIntoSubstringsArray(Attributes, ",", True);
	EndIf;
	
	AttributesStructure = New Structure;
	If TypeOf(Attributes) = Type("Structure") Or TypeOf(Attributes) = Type("FixedStructure") Then
		AttributesStructure = Attributes;
	ElsIf TypeOf(Attributes) = Type("Array") Or TypeOf(Attributes) = Type("FixedArray") Then
		For Each Attribute IN Attributes Do
			AttributesStructure.Insert(StrReplace(Attribute, ".", ""), Attribute);
		EndDo;
	Else
		Raise PlaceParametersIntoString(
			NStr("en = 'Invalid type of Attributes second parameter: %1'"),
			String(TypeOf(Attributes)));
	EndIf;
	
	FieldTexts = "";
	For Each KeyAndValue IN AttributesStructure Do
		FieldName   = ?(ValueIsFilled(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Key));
		
		Alias = TrimAll(KeyAndValue.Key);
		
		FieldTexts  = FieldTexts + ?(IsBlankString(FieldTexts), "", ",") + "
		|	" + FieldName + " AS " + Alias;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	|" + FieldTexts + "
	|FROM
	|	" + Ref.Metadata().FullName() + " AS
	|SpecifiedTableAlias
	|WHERE SpecifiedTableAlias.Ref = &Ref
	|";
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Result = New Structure;
	For Each KeyAndValue IN AttributesStructure Do
		Result.Insert(KeyAndValue.Key);
	EndDo;
	FillPropertyValues(Result, Selection);
	
	Return Result;
	
EndFunction

// Returns attribute value read from the infobase using the object link.
// 
//  If there is no access to the attribute, access rights exception occurs.
//  If it is required to read the attribute
//  regardless of the current user rights, then you should use preliminary transition to the privileged mode.
// 
// Parameters:
//  Ref       - ref to object, - catalog item, document, ...
//  AttributeName - String, for example, "Code".
// 
// Returns:
//  Arbitrary    - depends on the value type of read attribute.
// 
&AtServerNoContext
Function ObjectAttributeValue(Ref, AttributeName)
	
	Result = ObjectAttributesValues(Ref, AttributeName);
	Return Result[StrReplace(AttributeName, ".", "")];
	
EndFunction 

// It returns a reference to the common module by name.
//
// Parameters:
//  Name          - String - common module name, for example:
//                 "CommonUse",
//                 "CommonUseClient".
//
// Returns:
//  CommonModule.
//
&AtClientAtServerNoContext
Function CommonModule(Name)
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Metadata.CommonModules.Find(Name) <> Undefined Then
		Module = Eval(Name);
	Else
		Module = Undefined;
	EndIf;
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise PlaceParametersIntoString(
			NStr("en = 'Common module ""%1"" is not found.'"), Name);
	EndIf;
#Else
	Module = Eval(Name);
#If Not WebClient Then
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise PlaceParametersIntoString(
			NStr("en = 'Common module ""%1"" is not found.'"), Name);
	EndIf;
#EndIf
#EndIf
	
	Return Module;
	
EndFunction

// Returns True if the subsystem exists.
//
// Parameters:
//  SubsystemFullName - String. Full metadata object name, subsystem without words "Subsystem.".
//                        For example, StandardSubsystems.BasicFunctionality".
//
// Example of optional subsystem call:
//
//  If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement")
//  	Then AccessControlModule = CommonUse.CommonModule("AccessManagement");
//  	AccessManagementModule.<Method name>();
//  EndIf;
//
// Returns:
//  Boolean.
//
&AtServerNoContext
Function SubsystemExists(SubsystemFullName)
	
	If Not SSLVersionMeetsRequirements() Then
		Return False;
	EndIf;
	
	NamesSubsystems = NamesSubsystems();
	Return NamesSubsystems.Get(SubsystemFullName) <> Undefined;
	
EndFunction

// Returns matching of subsystem names and True value;
&AtServerNoContext
Function NamesSubsystems()
	
	Return New FixedMap(NamesSubordinateSubsystems(Metadata));
	
EndFunction

&AtServerNoContext
Function NamesSubordinateSubsystems(ParentSubsystem)
	
	names = New Map;
	
	For Each CurrentSubsystem IN ParentSubsystem.Subsystems Do
		
		names.Insert(CurrentSubsystem.Name, True);
		NamesOfSubordinate = NamesSubordinateSubsystems(CurrentSubsystem);
		
		For Each NameSubordinate IN NamesOfSubordinate Do
			names.Insert(CurrentSubsystem.Name + "." + NameSubordinate.Key, True);
		EndDo;
	EndDo;
	
	Return names;
	
EndFunction

// Returns the string presentation of the type. 
// For reference types it returns in the format "CatalogRef.ObjectName" or "DocumentRef.ObjectName".
// For other types it converts type to a string, for example, Number.
//
&AtServerNoContext
Function TypePresentationString(Type)
	
	Presentation = "";
	
	If IsReference(Type) Then
	
		DescriptionFull = Metadata.FindByType(Type).FullName();
		ObjectName = DecomposeStringIntoSubstringsArray(DescriptionFull, ".")[1];
		
		If Catalogs.AllRefsType().ContainsType(Type) Then
			Presentation = "CatalogRef";
		
		ElsIf Documents.AllRefsType().ContainsType(Type) Then
			Presentation = "DocumentRef";
		
		ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
			Presentation = "BusinessProcessRef";
		
		ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfCharacteristicTypesRef";
		
		ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfAccountsRef";
		
		ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfCalculationTypesRef";
		
		ElsIf Tasks.AllRefsType().ContainsType(Type) Then
			Presentation = "TaskRef";
		
		ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
			Presentation = "ExchangePlanRef";
		
		ElsIf Enums.AllRefsType().ContainsType(Type) Then
			Presentation = "EnumRef";
		
		EndIf;
		
		Result = ?(Presentation = "", Presentation, Presentation + "." + ObjectName);
		
	Else
		
		Result = String(Type);
		
	EndIf;
	
	Return Result;
	
EndFunction

// It converts an XML text to
// the value table, the table columns are created based on the description in XML.
//
// Parameters:
//  XML     - text in XML or ReadXML format.
//
// XML schema:
// <?xml version="1.0"
//  encoding="utf-8"?> <xs:schema attributeFormDefault="unqualified" elementFormDefault="qualified"
//  xmlns:xs="http://www.w3.org/2001/XMLSchema"> <xs:element
//  name="Items"> <xs:complexType>
//  <xs:sequence>
//  <xs:element maxOccurs="unbounded" name="Item">
//  <xs:complexType>
//  <xs:attribute name="Code" type="xs:integer" use="required" /> <xs:attribute
//  name="Name" type="xs:string" use="required" /> <xs:attribute
//  name="Socr" type="xs:string" use="required" /> <xs:attribute name="Index"
//  type="xs:string" use="required" /> </xs:complexType> </xs:element>
//  </xs:sequence> <xs:attribute
//  name="Description"
//  type="xs:string"
//  use="required" /> <xs:attribute name="Columns" type="xs:string"
//  use="required" /> </xs:complexType> </xs:element> </xs:schema>
//
// Examples of XML files, see in the sample configuration.
// 
// Useful example:
//   ClassifierTable = ReadXMLToTable (DataRegisters.AddressClassifier.
//       GetTemplate("RussiaAddressObjectsClassifier").GetText());
//
// Returns:
//  Structure with
// TableName fields - String
//   Data - ValuesTable.
//
&AtServerNoContext
Function ReadXMLToTable(Val XML)
	
	If TypeOf(XML) <> Type("XMLReader") Then
		Read = New XMLReader;
		Read.SetString(XML);
	Else
		Read = XML;
	EndIf;
	
	// Read the first node and check it.
	If Not Read.Read() Then
		Raise NStr("en = 'Empty XML'");
	ElsIf Read.Name <> "Items" Then
		Raise NStr("en = 'Error in XML structure'");
	EndIf;
	
	// Get the table description and create it.
	TableName = Read.GetAttribute("Description");
	ColumnNames = StrReplace(Read.GetAttribute("Columns"), ",", Chars.LF);
	Columns = StrLineCount(ColumnNames);
	
	ValueTable = New ValueTable;
	For Ct = 1 To Columns Do
		ValueTable.Columns.Add(StrGetLine(ColumnNames, Ct), New TypeDescription("String"));
	EndDo;
	
	// Fill in the values in the table.
	While Read.Read() Do
		
		If Read.NodeType = XMLNodeType.EndElement AND Read.Name = "Items" Then
			Break;
		ElsIf Read.NodeType <> XMLNodeType.StartElement Then
			Continue;
		ElsIf Read.Name <> "Item" Then
			Raise NStr("en = 'Error in XML structure'");
		EndIf;
		
		NewRow = ValueTable.Add();
		For Ct = 1 To Columns Do
			ColumnName = StrGetLine(ColumnNames, Ct);
			NewRow[Ct-1] = Read.GetAttribute(ColumnName);
		EndDo;
		
	EndDo;
	
	// Fill in the result
	Result = New Structure;
	Result.Insert("TableName", TableName);
	Result.Insert("Data", ValueTable);
	
	Return Result;
	
EndFunction

//	Converts the value table to array.
//	It can be used to transfer client the data received on the server as a value table only if the value table contains only the values that can be transferred to the client.
//
//	Received array contains structures at that
//	each structure repeats the structure of the value table columns.
//
//	It is not recommended to use
//	to convert value tables with a large number of strings.
//
//	Parameters:
//	ValueTable Return value: Array.
//
&AtServerNoContext
Function ValueTableToArray(ValueTable)
	
	Array = New Array();
	StructureString = "";
	CommaRequired = False;
	For Each Column IN ValueTable.Columns Do
		If CommaRequired Then
			StructureString = StructureString + ",";
		EndIf;
		StructureString = StructureString + Column.Name;
		CommaRequired = True;
	EndDo;
	For Each String IN ValueTable Do
		NewRow = New Structure(StructureString);
		FillPropertyValues(NewRow, String);
		Array.Add(NewRow);
	EndDo;
	Return Array;

EndFunction

&AtServerNoContext
Function SSLVersionMeetsRequirements()
	
	Try
		ModuleStandardSubsystemsServer = CommonModule("StandardSubsystemsServer");
	Except
		// Module does not exist
		ModuleStandardSubsystemsServer = Undefined;
	EndTry;
	If ModuleStandardSubsystemsServer = Undefined Then 
		Return False;
	EndIf;
	
	SSLVersion = ModuleStandardSubsystemsServer.LibraryVersion();
	Return VersionNumberToNumber(SSLVersion) >= VersionNumberToNumber("2.2.4.9");
	
EndFunction

&AtServerNoContext
Function VersionNumberToNumber(VersionNumber)
	NumberParts = DecomposeStringIntoSubstringsArray(VersionNumber, ".", True);
	If NumberParts.Count() <> 4 Then
		Return 0;
	EndIf;
	Result = 0;
	For Each NumberPart IN NumberParts Do
		Result = Result * 1000 + Number(NumberPart);
	EndDo;
	Return Result;
EndFunction

&AtServer
Function ValidateVersionAndPlatformCompatibilityMode()
	
	Information = New SystemInfo;
	If Not (Left(Information.AppVersion, 3) = "8.3"
		AND (Metadata.CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse
		Or (Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_1
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_2_13
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_2_16"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_1"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_2"]))) Then
		
		Raise NStr("en = 'DataProcessor is used to start
			|on 1C:Enterprise 8.3 platform version with compatibility mode off or above'");
		
	EndIf;
	
EndFunction

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
