// Form is parameterized.
//
// Parameters:
//     RefsList - Array, ValuesList - references set for analysis.
//                                             It can be a collection of items that have the Ref field.
//

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Transfer parameters to the UsagePlaces table.
	// Initialize the MainItem, ReplaceRefsCommonOwner, ParametersErrorText attributes.
	InitializeMergedRefs( RefsArrayFromSet(Parameters.RefSet) );
	If Not IsBlankString(ParametersErrorText) Then
		// A warning will be shown during opening;
		Return;
	EndIf;
	
	ObjectMetadata = MainItem.Ref.Metadata();
	PermanentlyDeletionRight = AccessRight("DataAdministration", Metadata) 
		Or AccessRight("InteractiveDelete", ObjectMetadata);
	EventReplacementNotifications        = DataProcessors.ReplaceAndCombineElements.EventReplacementNotifications();
	
	CurrentRemovalVariant = "Mark";
	StepByStepAssistantSettings = InitializeMaster(Items.AssistantSteps, Items.Next, Items.Back, Items.Cancel);
	
	// Add steps depending on the form logic.
	InitializeAssistantScript();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	// Need for an error message.
	If Not IsBlankString(ParametersErrorText) Then
		Cancel = True;
		ShowMessageBox(, ParametersErrorText);
		Return;
	EndIf;
	
	// Specify an initial page.
	SetAssistantInitialPage(Items.StepSearchUsagePlaces);
	RunAssistant();
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	// Check job.
	If StepByStepAssistantSettings.ProcedureName = "ReplaceRefs" // It is important to show only replacement result.
		AND StepByStepAssistantSettings.JobCompleted = False
		AND StepByStepAssistantSettings.BackgroundJobID <> Undefined
		AND StepByStepAssistantSettings.HasJobCancellationConfirmation = False Then
		Cancel = True;
		BackgroundJobImportOnClient(False, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If StepByStepAssistantSettings.JobCompleted = False
		AND StepByStepAssistantSettings.BackgroundJobID <> Undefined Then
		BackgroundJobCancel();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderEventHandlers

&AtClient
Procedure ToolTipSelectingBasicElementDataProcessorNavigationRefs(Item, NavigationRefValue, StandardProcessing)
	StandardProcessing = False;
	
	If NavigationRefValue = "RemovalModeSwitch" Then
		If CurrentRemovalVariant = "Directly" Then
			CurrentRemovalVariant = "Mark" 
		Else
			CurrentRemovalVariant = "Directly" 
		EndIf;
		FormMergingToolTip();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTablesEventItemsHandlersUsagePlaces

&AtClient
Procedure UsagePlacesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	Refs = UsagePlaces.FindByID(SelectedRow).Ref;
	
	If Field <> Items.UsagePlacesUsagePlaces Then
		ShowValue(, Refs);
		Return;
	EndIf;
	
	RefsSet = New Array;
	RefsSet.Add(Refs);
	SearchAndDeleteDuplicatesClient.ShowUsagePlacess(RefsSet);
	
EndProcedure

&AtClient
Procedure UsagePlacesBeforeAdding(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	If Copy Then
		Return;
	EndIf;
	
	// Add always everything of the same type as the main one.
	ChoiceFormName = ChoiceFormNameByRef(MainItem);
	If Not IsBlankString(ChoiceFormName) Then
		FormParameters = New Structure("Multiselect", True);
		If ReplaceableLinksCommonOwner <> Undefined Then
			FormParameters.Insert("Filter", New Structure("Owner", ReplaceableLinksCommonOwner));
		EndIf;
		OpenForm(ChoiceFormName, FormParameters, Item);
	EndIf;
EndProcedure

&AtClient
Procedure UsagePlacesBeforeDeletion(Item, Cancel)
	Cancel = True;
	
	CurrentData = Item.CurrentData;
	If CurrentData=Undefined Or UsagePlaces.Count()<3 Then
		Return;
	EndIf;
	
	Refs = CurrentData.Ref;
	Code    = String(CurrentData.Code);
	
	QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Remove the %1 item from the to merge list?';ru='Удалить из списка для объединения элемент ""%1""?'"),
		String(Refs) + ?(IsBlankString(Code), "", " (" + Code + ")" ));
	
	Notification = New NotifyDescription("UsagePlacesBeforeDeletionEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("CurrentRow", Item.CurrentRow);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo);
EndProcedure

&AtClient
Procedure UsagePlacesSelectionProcessing(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	
	If TypeOf(ValueSelected) = Type("Array") Then
		Adding = ValueSelected;
	Else
		Adding = New Array;
		Adding.Add(ValueSelected);
	EndIf;
	
	AddUsagePlacesRows(Adding);
	FormMergingToolTip();
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersFailedReplacements

&AtClient
Procedure FailedReplacementsOnActivateRow(Item)
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined Then
		DecryptionFailureReasons = "";
	Else
		DecryptionFailureReasons = CurrentData.DetailedReason;
	EndIf;
EndProcedure

&AtClient
Procedure FailedReplacementsSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	
	Refs = FailedReplacements.FindByID(SelectedRow).Ref;
	If Refs <> Undefined Then
		ShowValue(, Refs);
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure AssistantStepBack(Command)
	AssistantStep("Back");
EndProcedure

&AtClient
Procedure NextAssistantStep(Command)
	AssistantStep("Next");
EndProcedure

&AtClient
Procedure AssistantStepCancel(Command)
	AssistantStep("Cancel");
EndProcedure

&AtClient
Procedure OpenItemUsagePlace(Command)
	CurrentData = Items.UsagePlaces.CurrentData;
	If CurrentData <> Undefined Then
		ShowValue(, CurrentData.Ref);
	EndIf;
EndProcedure

&AtClient
Procedure UsagePlaces(Command)
	
	CurrentData = Items.UsagePlaces.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	RefsSet = New Array;
	RefsSet.Add(CurrentData.Ref);
	SearchAndDeleteDuplicatesClient.ShowUsagePlacess(RefsSet);
	
EndProcedure

&AtClient
Procedure AllUsagePlaces(Command)
	
	If UsagePlaces.Count() > 0 Then 
		SearchAndDeleteDuplicatesClient.ShowUsagePlacess(UsagePlaces);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetMain(Command)
	CurrentData = Items.UsagePlaces.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	MainItem = CurrentData.Ref;
	FormMergingToolTip();
EndProcedure

&AtClient
Procedure OpenFailedReplacementItem(Command)
	CurrentData = Items.FailedReplacements.CurrentData;
	If CurrentData <> Undefined Then
		ShowValue(, CurrentData.Ref);
	EndIf;
EndProcedure

&AtClient
Procedure ExpandAllFailedReplacements(Command)
	FormTree = Items.FailedReplacements;
	For Each Item IN FailedReplacements.GetItems() Do
		FormTree.Expand(Item.GetID(), True);
	EndDo;
EndProcedure

&AtClient
Procedure GroupAllFailedReplacements(Command)
	FormTree = Items.FailedReplacements;
	For Each Item IN FailedReplacements.GetItems() Do
		FormTree.Collapse(Item.GetID());
	EndDo;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		ImportantInscriptionFont = New Font(, , True);
	Else // Taxi.
		ImportantInscriptionFont = New Font("Arial", 10, True, False, False, False, 100);
	EndIf;
	
	Instruction = SearchAndDeleteDuplicates.ConditionalDesignInstruction();
	Condition = New Structure("Kind, Value", "NotEqual", New DataCompositionField("MainItem"));
	Instruction.Filters.Insert("UsagePlaces.Ref", Condition);
	Instruction.Fields = "UsagePlacesMain";
	Instruction.Design.Insert("Show", False);
	SearchAndDeleteDuplicates.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = SearchAndDeleteDuplicates.ConditionalDesignInstruction();
	Instruction.Filters.Insert("UsagePlaces.Ref", New DataCompositionField("MainItem"));
	Instruction.Fields = "UsagePlacesRef, UsagePlacesCode, UsagePlacesUsagePlaces";
	Instruction.Design.Insert("Font", ImportantInscriptionFont);
	SearchAndDeleteDuplicates.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = SearchAndDeleteDuplicates.ConditionalDesignInstruction();
	Instruction.Filters.Insert("UsagePlaces.UsagePlaces", New Structure("Kind, Value", "LessOrEqual", 0));
	Instruction.Fields = "UsagePlacesNotUsed";
	Instruction.Design.Insert("Visible", True);
	Instruction.Design.Insert("Show", True);
	SearchAndDeleteDuplicates.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = SearchAndDeleteDuplicates.ConditionalDesignInstruction();
	Instruction.Filters.Insert("UsagePlaces.UsagePlaces", New Structure("Kind, Value", "Greater", 0));
	Instruction.Fields = "UsagePlacesNotUsed";
	Instruction.Design.Insert("Visible", False);
	Instruction.Design.Insert("Show", False);
	SearchAndDeleteDuplicates.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = SearchAndDeleteDuplicates.ConditionalDesignInstruction();
	Instruction.Filters.Insert("UsagePlaces.UsagePlaces", New Structure("Kind, Value", "LessOrEqual", 0));
	Instruction.Fields = "UsagePlacesUsagePlaces";
	Instruction.Design.Insert("Visible", False);
	Instruction.Design.Insert("Show", False);
	SearchAndDeleteDuplicates.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = SearchAndDeleteDuplicates.ConditionalDesignInstruction();
	Instruction.Filters.Insert("FailedReplacements.Code", New Structure("Kind, Value", "NotFilled"));
	Instruction.Fields = "FailedReplacementsCode";
	Instruction.Design.Insert("Visible", False);
	Instruction.Design.Insert("Show", False);
	SearchAndDeleteDuplicates.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = SearchAndDeleteDuplicates.ConditionalDesignInstruction();
	Instruction.Filters.Insert("UsagePlaces.UsagePlaces", New Structure("Kind, Value", "Greater", 0));
	Instruction.Fields = "UsagePlacesUsagePlaces";
	Instruction.Design.Insert("Visible", True);
	Instruction.Design.Insert("Show", True);
	SearchAndDeleteDuplicates.AddConditionalAppearanceItem(ThisObject, Instruction);
	
EndProcedure

&AtServer
Procedure InitializeMergedRefs(Val RefArray)
	
	CheckResult = CheckMergedRefs(RefArray);
	ParametersErrorText = CheckResult.Error;
	If Not IsBlankString(ParametersErrorText) Then
		Return;
	EndIf;
	
	MainItem = RefArray[0];
	ReplaceableLinksCommonOwner = CheckResult.CommonOwner;
	
	UsagePlaces.Clear();
	For Each Item IN RefArray Do
		UsagePlaces.Add().Ref = Item;
	EndDo;
EndProcedure

&AtServerNoContext
Function CheckMergedRefs(Val RefsSet)
	
	Result = New Structure("Error, CommonOwner");
	
	QuantityRefs = RefsSet.Count();
	If QuantityRefs < 2 Then
		Result.Error = NStr("en='To merge, you should specify several items.';ru='Для объединения необходимо указать несколько элементов.'");
		Return Result;
	EndIf;
	
	FirstItem = RefsSet[0];
	
	MainMetadata = FirstItem.Metadata();
	Characteristics = New Structure("Owners, Hierarchical, HierarchyType", New Array, False);
	FillPropertyValues(Characteristics, MainMetadata);
	
	HasOwners = Characteristics.Owners.Count() > 0;
	HasFolders    = Characteristics.Hierarchical AND Characteristics.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems;
	
	AdditionalFields = "";
	If HasOwners Then
		AdditionalFields = AdditionalFields + ", Owner AS Owner";
	Else
		AdditionalFields = AdditionalFields + ", UNDEFINED AS Owner";
	EndIf;
	
	If HasFolders Then
		AdditionalFields = AdditionalFields + ", IsFolder AS IsFolder";
	Else
		AdditionalFields = AdditionalFields + ", FALSE AS IsFolder";
	EndIf;
	
	TableName = MainMetadata.FullName();
	Query = New Query("
		|SELECT Refs AS Ref" + AdditionalFields + " PLACE
		|ReplacedRefs FROM " + TableName + " WHERE Refs IN (&RefsSet)
		|INDEX BY Owner, IsFolder
		|;
		|SELECT 
		|	COUNT(DISTINCT Owner) AS OwnersQuantity,
		|	MIN(Owner)              AS CommonOwner,
		|	MAX(IsFolder)            AS HasFolders,
		|	COUNT(Refs)             AS QuantityRefs
		|FROM
		|	ReplaceReferences
		|");
	Query.SetParameter("RefsSet", RefsSet);
	
	Control = Query.Execute().Unload()[0];
	If Control.HasFolders Then
		Result.Error = NStr("en='One of the merged items is a group.
		|The groups can not be merged.';ru='Один из объединяемых элементов является группой.
		|Группы не могут быть объединены.'");
	ElsIf Control.OwnersQuantity > 1 Then 
		Result.Error = NStr("en='Merged items have different owners.
		|Such items can not be merged.';ru='У объединяемых элементов различные владельцы.
		|Такие элементы не могут быть объединены.'");
	ElsIf Control.QuantityRefs <> QuantityRefs Then
		Result.Error = NStr("en='All merged items should be of the same type.';ru='Все объединяемые элементы должны быть одного типа.'");
	Else 
		// Everything is ok
		Result.CommonOwner = ?(HasOwners, Control.CommonOwner, Undefined);
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Procedure UsagePlacesBeforeDeletionEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	// Actual removal from the table.
	String = UsagePlaces.FindByID(AdditionalParameters.CurrentRow);
	If String = Undefined Then
		Return;
	EndIf;
	
	RemovedRowIndex = UsagePlaces.IndexOf(String);
	CalculateMain     = String.Ref = MainItem;
	
	UsagePlaces.Delete(String);
	If CalculateMain Then
		IndexOfLastRow = UsagePlaces.Count() - 1;
		If RemovedRowIndex <= IndexOfLastRow Then 
			MainRowIndex = RemovedRowIndex;
		Else
			MainRowIndex = IndexOfLastRow;
		EndIf;
			
		MainItem = UsagePlaces[MainRowIndex].Ref;
	EndIf;
	
	FormMergingToolTip();
EndProcedure

&AtServer
Procedure FormMergingToolTip()

	If PermanentlyDeletionRight Then
		If CurrentRemovalVariant = "Mark" Then
			ToolTipText = NStr("en='Items (%1) will be <a href = ""DeletionModeSwitch > marked
		|for deletion</a> and replaced in all places of use with %2 (marked with an arrow).';ru='Элементы (%1) будут <a href = ""ПереключениеРежимаУдаления"">помечены на удаление</a> и заменены во всех местах
		|использования на ""%2"" (отмечен стрелкой).'");
		Else
			ToolTipText = NStr("en='Items (%1) will be <a href = ""DeletionModeSwitch > deleted permanently</a> and replaced in all places of use with %2 (marked with an arrow).';ru='Элементы (%1) будут <a href = ""ПереключениеРежимаУдаления"">удалены безвозвратно</a> и заменены во всех местах
		|использования на ""%2"" (отмечен стрелкой).'");
		EndIf;
	Else
		ToolTipText = NStr("en='Items (%1) will be marked for deletion and replaced
		|in all places of use with %2 (marked with an arrow).';ru='Элементы (%1) будут помечены на удаление
		|и заменены во всех местах использования на ""%2"" (отмечен стрелкой).'");
	EndIf;
		
	ToolTipText = StringFunctionsClientServer.PlaceParametersIntoString(ToolTipText, UsagePlaces.Count()-1, MainItem);
	Items.ToolTipSelectMainItem.Title = StringFunctionsClientServer.FormattedString(ToolTipText);
	
EndProcedure

&AtClient
Function EndingMessage()
	
	Return StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Items (%1) are merged to %2';ru='Элементы (%1) объединены в ""%2""'"),
		UsagePlaces.Count(),
		MainItem);
	
EndFunction

&AtClient
Procedure FormLabelFailedReplacements()
	
	Items.ResultFailedReplacements.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Items merging was not executed. IN some places of use an automatic
		|replacement with %1 can not be executed.';ru='Объединение элементов не выполнено. В некоторых местах использования не может быть произведена
		|автоматическая замена на ""%1"".'"),
		MainItem);
	
EndProcedure

// Parameters:
//     DataList - Array - contains changed data. You will be warned about its type.
//
&AtClient
Procedure SuccessfulReplacementAlert(Val DataList)
	// Change objects that had replacements in them.
	TypeList = New Map;
	For Each Item IN DataList Do
		Type = TypeOf(Item);
		If TypeList[Type] = Undefined Then
			NotifyChanged(Type);
			TypeList.Insert(Type, True);
		EndIf;
	EndDo;
	
	// Common alert
	If TypeList.Count() > 0 Then
		Notify(EventReplacementNotifications, , ThisObject);
	EndIf;
EndProcedure

&AtServer
Procedure FillUsagePlaces(Val UsageTable)
	
	NewUsagePlaces = UsagePlaces.Unload();
	NewUsagePlaces.Indexes.Add("Ref");
	
	IsUpdate = NewUsagePlaces.Find(MainItem, "Ref") <> Undefined;
	
	If Not IsUpdate Then
		NewUsagePlaces = UsagePlaces.Unload(New Array);
		NewUsagePlaces.Indexes.Add("Ref");
	EndIf;
	
	MetadataCache = New Map;
	
	MaxRef = Undefined;
	MaxPlaces   = -1;
	For Each String IN UsageTable Do
		Refs = String.Ref;
		
		UsingRow = NewUsagePlaces.Find(Refs, "Ref");
		If UsingRow = Undefined Then
			UsingRow = NewUsagePlaces.Add();
			UsingRow.Ref = Refs;
		EndIf;
		
		Places = String.Listings;
		If Places>MaxPlaces
			AND Not Refs.DeletionMark Then
			MaxRef = Refs;
			MaxPlaces   = Places;
		EndIf;
		
		UsingRow.UsagePlaces = Places;
		UsingRow.Code      = PossibleRefCode(Refs, MetadataCache);
		UsingRow.Owner = PossibleRefOwner(Refs, MetadataCache);
		
		UsingRow.NotUsed = ?(Places = 0, NStr("en='Not Used';ru='Не используется'"), "");
	EndDo;
	
	UsagePlaces.Load(NewUsagePlaces);
	
	If MaxRef <> Undefined Then
		MainItem = MaxRef;
	EndIf;
	
	// Update titles
	Presentation = ?(MainItem=Undefined, "", MainItem.Metadata().Presentation());
	
	HeaderText = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Merge %1 items to one';ru='Объединение элементов %1 в один'"),
		Presentation
	);
EndProcedure

&AtServer
Function FillFailedReplacements(Val ReplacementResults)
	// ReplacementResults - table with the Link, ErrorObject, ErrorType, ErrorText columns.
	RootRows = FailedReplacements.GetItems();
	RootRows.Clear();
	
	RowsMatch = New Map;
	MetadataCache     = New Map;
	
	For Each ResultRow IN ReplacementResults Do
		Refs = ResultRow.Ref;
		
		ErrorsOnRef = RowsMatch[Refs];
		If ErrorsOnRef = Undefined Then
			TreeRow = RootRows.Add();
			TreeRow.Ref = Refs;
			TreeRow.Data = String(Refs);
			TreeRow.Code    = String( PossibleRefCode(Refs, MetadataCache) );
			TreeRow.Icon = -1;
			
			ErrorsOnRef = TreeRow.GetItems();
			RowsMatch.Insert(Refs, ErrorsOnRef);
		EndIf;
		
		ErrorString = ErrorsOnRef.Add();
		ErrorString.Ref = ResultRow.ErrorObject;
		ErrorString.Data = ResultRow.ErrorObjectPresentation;
		
		ErrorType = ResultRow.ErrorType;
		If ErrorType = "UnknownData" Then
			ErrorString.Cause = NStr("en='Data is found that was not planned to be processed.';ru='Обнаружена данные, обработка которых не планировалась.'");
			
		ElsIf ErrorType = "LockError" Then
			ErrorString.Cause = NStr("en='The data is locked by another user.';ru='Данные заблокированы другим пользователем.'");
			
		ElsIf ErrorType = "DataChanged" Then
			ErrorString.Cause = NStr("en='The data was changed by another user.';ru='Данные изменены другим пользователем.'");
			
		ElsIf ErrorType = "RecordingError" Then
			ErrorString.Cause = ResultRow.ErrorText;
			
		ElsIf ErrorType = "ErrorDelete" Then
			ErrorString.Cause = NStr("en='Unable to delete data.';ru='Невозможно удалить данные.'");
			
		Else
			ErrorString.Cause = NStr("en='Unknown error.';ru='Неизвестная ошибка.'");
			
		EndIf;
		
		ErrorString.DetailedReason = ResultRow.ErrorText;
	EndDo; // replacement results
	
	Return RootRows.Count() > 0;
EndFunction

&AtServerNoContext
Function ChoiceFormNameByRef(Val Refs)
	Meta = Metadata.FindByType(TypeOf(Refs));
	Return ?(Meta = Undefined, Undefined, Meta.FullName() + ".ChoiceForm");
EndFunction

// Converts an array, a values list or collection to an array.
//
&AtServerNoContext
Function RefsArrayFromSet(Val Refs)
	
	ParameterType = TypeOf(Refs);
	If Refs = Undefined Then
		RefArray = New Array;
		
	ElsIf ParameterType  = Type("ValueList") Then
		RefArray = Refs.UnloadValues();
		
	ElsIf ParameterType = Type("Array") Then
		RefArray = Refs;
		
	Else
		RefArray = New Array;
		For Each Item IN Refs Do
			RefArray.Add(Item.Ref);
		EndDo;
		
	EndIf;
	
	Return RefArray;
EndFunction

// Adds references array
&AtServer
Procedure AddUsagePlacesRows(Val RefArray)
	LastIndex = Undefined;
	MetadataCache    = New Map;
	
	Filter = New Structure("Ref");
	For Each Refs IN RefArray Do
		Filter.Ref = Refs;
		ExistingRows = UsagePlaces.FindRows(Filter);
		If ExistingRows.Count() = 0 Then
			String = UsagePlaces.Add();
			String.Ref = Refs;
			
			String.Code      = PossibleRefCode(Refs, MetadataCache);
			String.Owner = PossibleRefOwner(Refs, MetadataCache);
			
			String.UsagePlaces = -1;
			String.NotUsed    = NStr("en='Not calculated';ru='Не рассчитано'");
		Else
			String = ExistingRows[0];
		EndIf;
		
		LastIndex = String.GetID();
	EndDo;
	
	If LastIndex <> Undefined Then
		Items.UsagePlaces.CurrentRow = LastIndex;
	EndIf;
EndProcedure

// Returns:
//     Arbitrary - catalog code etc if it exists according to metadata, Undefined - if there is no code.
//
&AtServerNoContext
Function PossibleRefCode(Val Refs, MetadataCache)
	Data = MetaDescriptionByReference(Refs, MetadataCache);
	Return ?(Data.ThereIsCode, Refs.Code, Undefined);
EndFunction

// Returns:
//     Arbitrary - catalog owner if it exists according to metadata, Undefined - if there is no owner.
//
&AtServerNoContext
Function PossibleRefOwner(Val Refs, MetadataCache)
	Data = MetaDescriptionByReference(Refs, MetadataCache);
	Return ?(Data.HasOwner, Refs.Owner, Undefined);
EndFunction

// Returns the description of catalog etc by metadata.
&AtServerNoContext
Function MetaDescriptionByReference(Val Refs, MetadataCache)
	
	ObjectMetadata = Refs.Metadata();
	Data = MetadataCache[ObjectMetadata];
	
	If Data = Undefined Then
		Test = New Structure("CodeLength, Owners", 0, New Array);
		FillPropertyValues(Test, ObjectMetadata);
		
		Data = New Structure;
		Data.Insert("ThereIsCode", Test.CodeLength > 0);
		Data.Insert("HasOwner", Test.Owners.Count() > 0);
		
		MetadataCache[ObjectMetadata] = Data;
	EndIf;
	
	Return Data;
EndFunction

// Returns the list of successfully replaced references that are missing in FailedReplacements.
&AtClient
Function DeleteFromUsePlacesProcessed()
	Result = New Array;
	
	Failed = New Map;
	For Each String IN FailedReplacements.GetItems() Do
		Failed.Insert(String.Ref, True);
	EndDo;
	
	IndexOf = UsagePlaces.Count() - 1;
	While IndexOf > 0 Do
		Refs = UsagePlaces[IndexOf].Ref;
		If Refs<>MainItem AND Failed[Refs] = Undefined Then
			UsagePlaces.Delete(IndexOf);
			Result.Add(Refs);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Return Result;
EndFunction

// Check the possibility of replacement from the applied point of view.
&AtServer
Function CheckReplaceReferencesPossibility()
	
	RefsSet = New Array;
	SubstitutionsPairs   = New Map;
	For Each String IN UsagePlaces Do
		RefsSet.Add(String.Ref);
		SubstitutionsPairs.Insert(String.Ref, MainItem);
	EndDo;
	
	// Check possibly changed set once again.
	Control = CheckMergedRefs(RefsSet);
	If Not IsBlankString(Control.Error) Then
		Return Control.Error;
	EndIf;
	
	ReplacementParameters = New Structure("RemovalMethod", CurrentRemovalVariant);
	Return SearchAndDeleteDuplicates.CheckItemsReplacePossibilityRow(SubstitutionsPairs, ReplacementParameters);
	
EndFunction

&AtServer
Procedure InitializeAssistantScript()
	
	// 0. Search for places of use by parameters.
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Visible = False;
	ButtonsAssistant.Next.Visible = False;
	ButtonsAssistant.Cancel.Title = NStr("en='Break';ru='Прервать'");
	ButtonsAssistant.Cancel.ToolTip = NStr("en='Cancel items merging';ru='Отказаться от объединения элементов'");
	
	AddAssistantStep(Items.StepSearchUsagePlaces, 
		AssistantStepAction("OnActivating",         "StepSearchUsePlacesOnActivating",
		AssistantStepAction("BeforeCancelAction", "StepSearchUsePlacesBeforeCancelAction",
		AssistantStepAction("OnProcessWaiting", "StepSearchUsePlacesOnProcessWaiting"))), 
		ButtonsAssistant);
	
	// 1. Select the main item.
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Visible = False;
	ButtonsAssistant.Next.DefaultButton = True;
	ButtonsAssistant.Next.Title = NStr("en='Merge >';ru='Объединить >'");
	ButtonsAssistant.Next.ToolTip = NStr("en='Begin items merging';ru='Начать объединение элементов'");
	ButtonsAssistant.Cancel.Title = NStr("en='Cancel';ru='Отменить'");
	ButtonsAssistant.Cancel.ToolTip = NStr("en='Cancel items merging';ru='Отказаться от объединения элементов'");
	
	AddAssistantStep(Items.StepSelectMainItem, 
		AssistantStepAction("OnActivating",         "StepSelectMainItemOnActivating",
		AssistantStepAction("BeforeNextAction",  "StepSelectMainItemBeforeNextAction",
		AssistantStepAction("BeforeCancelAction", "StepSelectMainItemBeforeCancelAction"))), 
		ButtonsAssistant);
	
	// 2. Waiting for a process
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Visible = False;
	ButtonsAssistant.Next.Visible = False;
	ButtonsAssistant.Cancel.Title = NStr("en='Break';ru='Прервать'");
	ButtonsAssistant.Cancel.ToolTip = NStr("en='Break items merging';ru='Прервать объединение элементов'");
	
	AddAssistantStep(Items.StepMerging, 
		AssistantStepAction("OnActivating",         "StepMergingOnActivating",
		AssistantStepAction("BeforeCancelAction", "StepMergingBeforeCancelAction",
		AssistantStepAction("OnProcessWaiting", "StepMergingOnProcessWaiting"))), 
		ButtonsAssistant);
	
	// 3. Successful merging
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Visible = False;
	ButtonsAssistant.Next.Visible = False;
	ButtonsAssistant.Cancel.DefaultButton = True;
	ButtonsAssistant.Cancel.Title = NStr("en='Close';ru='Закрыть'");
	ButtonsAssistant.Cancel.ToolTip = NStr("en='Close merging results';ru='Закрыть результаты объединения'");
	
	AddAssistantStep(Items.SuccessfulCompletionStep, 
		AssistantStepAction("OnActivating",         "StepSuccessfulCompletionOnActivating",
		AssistantStepAction("BeforeCancelAction", "StepSuccessfulCompletionBeforeCancelAction")), 
		ButtonsAssistant);
	
	// 4. Errors of reference replacements
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Title = NStr("en='< Home';ru='< Home'");
	ButtonsAssistant.Back.ToolTip = NStr("en='Return to the main item selection';ru='Вернутся к выбору основного элемента'");
	ButtonsAssistant.Next.DefaultButton = True;
	ButtonsAssistant.Next.Title = NStr("en='Retry';ru='Повторить'");
	ButtonsAssistant.Next.ToolTip = NStr("en='Repeat merging';ru='Повторить объединение'");
	ButtonsAssistant.Cancel.Title = NStr("en='Cancel';ru='Отменить'");
	ButtonsAssistant.Cancel.ToolTip = NStr("en='Close merging results';ru='Закрыть результаты объединения'");
	
	AddAssistantStep(Items.RepeatMergingStep,
		AssistantStepAction("OnActivating",         "StepRepeatMergingOnActivating",
		AssistantStepAction("BeforeNextAction",  "StepRepeatMergingBeforeNextAction",
		AssistantStepAction("BeforeBackAction",  "StepRepeatMergingBeforeBackAction",
		AssistantStepAction("BeforeCancelAction", "StepRepeatMergingBeforeCancelAction")))), 
		ButtonsAssistant);
EndProcedure

&AtClient
Procedure StepSearchUsePlacesOnActivating(Val Page, Val AdditionalParameters) Export
	BackGroundJobStart("DefineUsagePlacess");
EndProcedure

&AtClient
Procedure StepSearchUsePlacesOnProcessWaiting(Stop, Val AdditionalParameters) Export
	If BackgroundJobImportOnClient(False, False) Then
		Stop = True;
	EndIf;
EndProcedure

&AtClient
Procedure StepSearchUsePlacesBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	CheckBackgroundJobAndCloseFormWithoutConfirmation();
EndProcedure

&AtClient
Procedure StepSelectMainItemOnActivating(Val Page, Val AdditionalParameters) Export
	
	FormMergingToolTip();
	
EndProcedure

&AtClient
Procedure StepSelectMainItemBeforeNextAction(Val StepParameters, Val AdditionalParameters) Export
	
	// Check validity of the shared use from an applied point of view.
	ErrorText = CheckReplaceReferencesPossibility();
	
	If IsBlankString(ErrorText) Then
		// All replacements are allowed
		AssistantStepEnd(StepParameters);
		Return;
	EndIf;
	
	WarningParameters = New Structure;
	WarningParameters.Insert("Title", NStr("en='Unable to merge items';ru='Невозможно объединить элементы'"));
	WarningParameters.Insert("MessageText", ErrorText);
	OpenForm("DataProcessor.ReplaceAndCombineElements.Form.MultilineWarning", WarningParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure StepSelectMainItemBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	Close();
EndProcedure

&AtClient
Procedure StepMergingOnActivating(Val Page, Val AdditionalParameters) Export
	BackGroundJobStart("ReplaceRefs");
EndProcedure

&AtClient
Procedure StepMergingOnProcessWaiting(Stop, Val AdditionalParameters) Export
	If BackgroundJobImportOnClient(False, False) Then
		Stop = True;
	EndIf;
EndProcedure

&AtClient
Procedure StepMergingBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	CheckBackgroundJobAndCloseFormWithoutConfirmation();
EndProcedure

&AtClient
Procedure StepSuccessfulCompletionOnActivating(Val Page, Val AdditionalParameters) Export
	
	Items.MergingResult.Title = EndingMessage();
	
	UpdatedList = New Array;
	For Each String IN UsagePlaces Do
		UpdatedList.Add(String.Ref);
	EndDo;
	SuccessfulReplacementAlert(UpdatedList);
	
EndProcedure

&AtClient
Procedure StepSuccessfulCompletionBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	AssistantStepEnd(StepParameters);
	If IsOpen() Then
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure StepRepeatMergingOnActivating(Val Page, Val AdditionalParameters) Export
	// Update failures quantity.
	FormLabelFailedReplacements();
	
	// Alert if a partial replacement was successful.
	UpdatedList = DeleteFromUsePlacesProcessed();	// Remove from the variants list at the same time.
	SuccessfulReplacementAlert(UpdatedList);
EndProcedure

&AtClient
Procedure StepRepeatMergingBeforeNextAction(Val StepParameters, Val AdditionalParameters) Export
	// Repeat replacement
	GoToAssistantStep(Items.StepMerging, True);
EndProcedure

&AtClient
Procedure StepRepeatMergingBeforeBackAction(Val StepParameters, Val AdditionalParameters) Export
	// Refill the list of processed.
	GoToAssistantStep(Items.StepSearchUsagePlaces, True);
EndProcedure

&AtClient
Procedure StepRepeatMergingBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	Close();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF A STEPPED WIZARD

&AtServer
Function InitializeMaster(Val PagesGroup, Val ButtonNext, Val ButtonBack, Val ButtonCancel)
	// Initializes assistant structures.
	//
	// Parameters:
	//     PagesGroup - FormGroup - An item of a form, a group of the page type containing assistant pages-steps.
	//     ButtonNext   - FormButton, CommandBarButton - Form item used for the Next button.
	//     ButtonBack   - FormButton, CommandBarButton - Form item used for the Back button.
	//     ButtonCancel  - FormButton, CommandBarButton - Form item used for the Cancel button.
	
	Result = New Structure;
	
	Result.Insert("Steps", New Array);
	Result.Insert("CurrentStepNumber", 0);
	Result.Insert("StartPage", Undefined);
	
	// Identifiers of the interface parts.
	Result.Insert("PagesGroup", PagesGroup.Name);
	Result.Insert("ButtonNext",   ButtonNext.Name);
	Result.Insert("ButtonBack",   ButtonBack.Name);
	Result.Insert("ButtonCancel",  ButtonCancel.Name);
	
	// The handler call timeout
	Result.Insert("LongOperationWaitingTimeout", 
		?( GetClientConnectionSpeed() = ClientConnectionSpeed.Low, 4, 2) );
		
	// To process long actions.
	Result.Insert("BackgroundJobID");
	Result.Insert("BackgroundJobResultAddress");
	Result.Insert("ErrorInfo");
	Result.Insert("JobCompleted", False);
	Result.Insert("ProcedureName");
	Result.Insert("HasJobCancellationConfirmation", False);
	
	// To store custom parameters.
	Result.Insert("CustomParameters", New Map);
	
	Return Result;
EndFunction

// Adds the assistant step. Transitions between pages will happen according to the order of adding.
//
// Parameters:
//
//     Page - FormGroup - Group-page containing items of a current page step.
// 
//     Actions - Structure - Description of actions that are possible to be executed on the current step. Structure fields:
//
//          * OnActivating      - String - Optional name of the procedure that
//                                         will be executed before activating a page with two parameters.:
//                                           <Page> - FormGroup - group-page that is being activated.
//                                           <AdditionalParameters> - Undefined
//
//          * BeforeNextAction  - String - Optional name of a procedure that will
//                                            be executed after clicking the Next button before going to the next page. The procedure will
//                                            be called with two parameters:
//                                              <StepParameters> - service attribute. If a chain
//                                                                of modeless calls is successfully
//                                                                ended, the last procedure-handler should execute a call.
//                                                                AssistantStepEnd(StepParameter) confirming an action.
//                                             <AdditionalParameters> - Undefined
//
//          * BeforeBackAction  - String - Same as BeforeNextAction it describes the
//                                            behavior of the Next button click.
//
//          * BeforeCancelAction - String - Same as BeforeNextAction it describes the
//                                            behavior of the Cancel button click.
//
//          * OnProcessWaiting - String - Optional name of the procedure that
//                                            will be periodically called with two parameters.:
//                                              <Stop> - If you set the True value when
//                                                             you leave the procedure, then periodic calls will be terminated.
//                                              <AdditionalParameters> - Undefined
//
//      Buttons - Structure - descriptions of buttons on the current step. Structure fields:
//
//          * Next  - Structure - The Next button description. fields: Title, ToolTip, Enabled,
//                                 Visible, DefaultButton.
//                                 An empty tooltip is replaced with a title. Default values will be used:
//                                 Title = "Next >", Enabled = True, Visible = True, DefaultButton = True;
//
//          * Back  - Structure - Same as the Next button, default values:
//                                 Title = "< Back", Enabled = True, Visible = True, DefaultButton = False;
//
//          * Cancel - Structure - Same as the Next button, default values:
//                                 Title = "Cancel", Enabled = True, Visible = True, DefaultButton = False;
//
// To compose parameters, it is recommended to use the AddAssistantStep, AssistantStepAction, AssistantButtons helper methods.
//
&AtServer
Procedure AddAssistantStep(Val Page, Val Actions, Val Buttons)
	
	// Defaults
	StepDescription = New Structure("OnActivating, BeforeNextAction, BeforeBackAction, BeforeCancelAction, OnProcessWaiting");
	
	ButtonFields = "Enabled, Visible, DefaultButton, ToolTip";
	
	StepDescription.Insert("ButtonNext", New Structure(ButtonFields, True, True, True));
	StepDescription.ButtonNext.Insert("Title", NStr("en='Next >';ru='Далее  >'"));
	
	StepDescription.Insert("ButtonBack", New Structure(ButtonFields, True, True, False));
	StepDescription.ButtonBack.Insert("Title", NStr("en='< Back';ru='< Back'"));
	
	StepDescription.Insert("ButtonCancel",New Structure(ButtonFields, True, True, False));
	StepDescription.ButtonCancel.Insert("Title", NStr("en='Cancel';ru='Отменить'"));
	
	StepDescription.Insert("Page", Page.Name);
	
	// Set actions
	FillPropertyValues(StepDescription, Actions);
	
	If Buttons.Property("Next") Then
		FillPropertyValues(StepDescription.ButtonNext, Buttons.Next);
	EndIf;
	If Buttons.Property("Back") Then
		FillPropertyValues(StepDescription.ButtonBack, Buttons.Back);
	EndIf;
	If Buttons.Property("Cancel") Then
		FillPropertyValues(StepDescription.ButtonCancel, Buttons.Cancel);
	EndIf;

	StepByStepAssistantSettings.Steps.Add(StepDescription);
EndProcedure

// Helper formation of a structure describing the action.
//
// Parameters:
//     ID    - String - Action identifier, see description of the AddMasterStep method.
//     HandlerName   - String - Name of the procedure, see description of the AddMasterStep method.
//     ServiceData  - Structure - Accumulates values.
//
// Returns - Structure - Service data with added fields.
&AtServer
Function AssistantStepAction(Val ID, Val HandlerName, ServiceData = Undefined)
	If ServiceData = Undefined Then
		ServiceData = New Structure;
	EndIf;
	ServiceData.Insert(ID, HandlerName);;
	Return ServiceData;
EndFunction

// Helper formation of a structure describing the assistant buttons.
//
// Returns:
//   Structure - Assistant buttons.
//       * Back  - Structure - Description of the Back button formed using the AssistantButton() method.
//       * Next  - Structure - Description of the Next button formed using the AssistantButton() method.
//       * Cancel - Structure - Description of the Cancel button generated by the AssistantButton method().
//
&AtServer
Function ButtonsAssistant()
	
	Result = New Structure("Next, Back, Cancel", AssistantButton(), AssistantButton(), AssistantButton());
	Result.Next.DefaultButton = True;
	Result.Next.Title = NStr("en='Next >';ru='Далее  >'");
	Result.Back.Title = NStr("en='< Back';ru='< Back'");
	Result.Cancel.Title = NStr("en='Cancel';ru='Отменить'");
	Return Result;
	
EndFunction

// Description of the assistant button settings.
//
// Returns:
//   Structure - Button of form settings.
//       * Title         - String - Button title.
//       Pop-up help         - String - ToolTip for button.
//       * Visible         - Boolean - If True, then the button is visible. Default value: True.
//       * Availability       - Boolean - If true, then you can click the button. Default value: True.
//       *DefaultButton - Boolean - If True, then the button will be the main button of a form. Value by default:
//                                      False.
//
// See also:
//   FormButton in the syntax-helper.
//
&AtServer
Function AssistantButton()
	Result = New Structure;
	Result.Insert("Title", "");
	Result.Insert("ToolTip", "");
	
	Result.Insert("Enabled", True);
	Result.Insert("Visible", True);
	Result.Insert("DefaultButton", False);
	
	Return Result;
EndFunction

// Sets an initial page for the first assistant launch.
//
// Parameters:
//     StartPage - Number, String, FormGroup - Number of a step, group-page, or its identifier.
//
&AtClient
Procedure SetAssistantInitialPage(Val Page)
	
	StepByStepAssistantSettings.StartPage = AssistantStepNumberByIdentifier(Page);
	
EndProcedure

// Launches the assistant from the step previously set using SetInitialMasterPage.
&AtClient
Procedure RunAssistant()
	If StepByStepAssistantSettings.StartPage = Undefined Then
		Raise NStr("en='Before launching the master, an initial page should be set.';ru='Перед запуском мастера должна быть установлена начальная страница.'");
		
	ElsIf StepByStepAssistantSettings.StartPage = -1 Then
		// Warming up. Check if all steps have action handlers.
		PossibleActions = New Structure("OnActivating, BeforeNextAction, BeforeBackAction, BeforeCancelAction, OnProcessWaiting");
		For Each StepDescription IN StepByStepAssistantSettings.Steps Do
			For Each KeyValue IN PossibleActions Do
				NameActions = KeyValue.Key;
				HandlerName = StepDescription[NameActions];
				If Not IsBlankString(HandlerName) Then
					Try
						Test = New NotifyDescription(HandlerName, ThisObject);
					Except
						Text = StringFunctionsClientServer.PlaceParametersIntoString(
							NStr("en='Error of %1 event handler creation for %2 page, %3 procedure is not defined';ru='Ошибка создания обработчика события %1 для страницы %2, не определена процедура %3'"),
							NameActions, 
							StepDescription.Page, 
							HandlerName
						);
						Raise Text;
					EndTry;
				EndIf;
			EndDo;
		EndDo;
		
		// Actual launch
		GoToAssistantStep(StepByStepAssistantSettings.CurrentStepNumber, True);
	Else
		// Everything is disabled by default
		Items[StepByStepAssistantSettings.ButtonNext].Visible  = False;
		Items[StepByStepAssistantSettings.ButtonBack].Visible  = False;
		Items[StepByStepAssistantSettings.ButtonCancel].Visible = False;
		
		// Deferred launch
		StepByStepAssistantSettings.CurrentStepNumber = StepByStepAssistantSettings.StartPage;
		StepByStepAssistantSettings.StartPage    = -1;
		AttachIdleHandler("RunAssistant", 0.1, True);
	EndIf;
EndProcedure

// Switches the assistant to the next or previous page.
//
// Parameters:
//     CommandCode - String - Action identifier, possible values are Next, Back or Cancel.
//
&AtClient
Procedure AssistantStep(Val CommandCode)
	If CommandCode = "Next" Then
		Direction = 1;
	ElsIf CommandCode = "Back" Then
		Direction = -1;
	ElsIf CommandCode = "Cancel" Then
		Direction = 0;
	Else
		Raise NStr("en='Incorrect command of the assistant step';ru='Некорректная команда шага помощника'");
	EndIf;
		
	StepDescription = StepByStepAssistantSettings.Steps[StepByStepAssistantSettings.CurrentStepNumber];
	
	// Stop handler if any.
	If StepDescription.OnProcessWaiting <> Undefined Then
		DetachIdleHandler("AssistantPageIdleProcessing");
	EndIf;
	
	// Process the current page leaving.
	If Direction = 1 Then
		Action = StepDescription.BeforeNextAction;
		
	ElsIf Direction = -1 Then
		Action = StepDescription.BeforeBackAction;
		
	Else
		Action = StepDescription.BeforeCancelAction;
		
	EndIf;
	
	If IsBlankString(Action) Then
		AssistantStepEnd(Direction);
	Else
		Notification = New NotifyDescription(Action, ThisObject);
		ExecuteNotifyProcessing(Notification, Direction);
	EndIf;
EndProcedure

// Performs an unconditional positioning of assistant to a page.
//
// Parameters:
//     IdentifierStep   - Number, String, FormGroup - Number, group-page of a form or its name for transfer.
//     TriggerEvents - Boolean - The check box showing that the events connected with a step activation should be called.
//
&AtClient
Procedure GoToAssistantStep(Val IdentifierStep, Val TriggerEvents = False)
	NextStep = AssistantStepNumberByIdentifier(IdentifierStep);
	If NextStep = Undefined Then
		Error = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='%1 assistant step is not found';ru='Не найден шаг помощника %1'"),
			IdentifierStep
		);
		Raise Error;
	EndIf;
		
	StepDescription = StepByStepAssistantSettings.Steps[StepByStepAssistantSettings.CurrentStepNumber];
	
	// Stop handler if any.
	If StepDescription.OnProcessWaiting <> Undefined Then
		DetachIdleHandler("AssistantPageIdleProcessing");
	EndIf;
	
	// And launch a new page
	StepEndAssistantUnconditionally(NextStep, TriggerEvents);
EndProcedure

// Confirms the action of assistant step and invokes a page switch.
//
// Parameters:
//     StepParameters - Service attribute received in the handler before the action began.
//
&AtClient
Procedure AssistantStepEnd(Val StepParameters)
	NextStep = StepByStepAssistantSettings.CurrentStepNumber + StepParameters;
	LastStep = StepByStepAssistantSettings.Steps.UBound();
	
	If StepParameters = 0 Then
		// Confirm cancellation - do nothing.
		Return;
		
	ElsIf StepParameters = 1 AND NextStep > LastStep Then
		// You are trying to take a step outside forward.
		Raise NStr("en='You are trying to go out of the assistant last step.';ru='Попытка выхода за последний шаг мастера'");
		
	ElsIf StepParameters = -1 AND NextStep < 0 Then
		// You are trying to take a step outside back.
		Raise NStr("en='You are trying to go back from the assistant first step.';ru='Попытка выхода назад из первого шага мастера'");
		
	EndIf;
	
	StepEndAssistantUnconditionally(NextStep);
EndProcedure

&AtClient
Procedure StepEndAssistantUnconditionally(Val NextStep, Val TriggerEvents = True)
	StepDescription = StepByStepAssistantSettings.Steps[NextStep];
	LastStep = StepByStepAssistantSettings.Steps.UBound();
	
	// Swith to a new page.
	Items[StepByStepAssistantSettings.PagesGroup].CurrentPage = Items[StepDescription.Page];
	// Crawl the platform feature.
	MasterPagesGroup = Items[StepByStepAssistantSettings.PagesGroup];
	NewCurrentPage = Items[StepDescription.Page];
	GroupKindPage = FormGroupType.Page;
	TypeFormGroup    = Type("FormGroup");
	For Each Page IN MasterPagesGroup.ChildItems Do
		If TypeOf(Page) = TypeFormGroup AND Page.Type = GroupKindPage Then
			Page.Visible = (Page = NewCurrentPage);
		EndIf;
	EndDo;
	
	// Update buttons
	UpdateAssistantButtonProperties(StepByStepAssistantSettings.ButtonNext,  StepDescription.ButtonNext);
	UpdateAssistantButtonProperties(StepByStepAssistantSettings.ButtonBack,  StepDescription.ButtonBack);
	UpdateAssistantButtonProperties(StepByStepAssistantSettings.ButtonCancel, StepDescription.ButtonCancel);
	
	// Successfully transferred
	StepByStepAssistantSettings.CurrentStepNumber = NextStep;
	
	If TriggerEvents AND Not IsBlankString(StepDescription.OnActivating) Then
		// Process OnActivating of a new page, it will launch the waiting.
		AttachIdleHandler("AssistantPageActivationProcessor", 0.1, True);
		
	ElsIf Not IsBlankString(StepDescription.OnProcessWaiting) Then
		// Launch waiting handler if needed.
		AttachIdleHandler("AssistantPageIdleProcessing", 0.1, True);
		
	EndIf;
EndProcedure

&AtClient
Procedure UpdateAssistantButtonProperties(Val ButtonName, Val Description)
	
	AssistantButton = Items[ButtonName];
	FillPropertyValues(AssistantButton, Description);
	AssistantButton.ExtendedTooltip.Title = Description.ToolTip;
	
EndProcedure

&AtClient
Procedure AssistantPageActivationProcessor()
	StepDescription = StepByStepAssistantSettings.Steps[StepByStepAssistantSettings.CurrentStepNumber];
	If Not IsBlankString(StepDescription.OnActivating) Then
		Notification = New NotifyDescription(StepDescription.OnActivating, ThisObject);
		ExecuteNotifyProcessing(Notification, Items[StepDescription.Page]);
	EndIf;
	
	// And launch waiting if needed.
	If Not IsBlankString(StepDescription.OnProcessWaiting) Then
		// First launch fast
		AttachIdleHandler("AssistantPageIdleProcessing", 0.1, True);
	EndIf;
EndProcedure

// It can be the number of a step, or a group-page, or its identifier.
&AtClient
Function AssistantStepNumberByIdentifier(Val IdentifierStep)
	ParameterType = TypeOf(IdentifierStep);
	If ParameterType = Type("Number") Then
		Return IdentifierStep;
	EndIf;
	
	SearchName = ?(ParameterType = Type("FormGroup"), IdentifierStep.Name, IdentifierStep);
	For StepNumber=0 To StepByStepAssistantSettings.Steps.UBound() Do
		If StepByStepAssistantSettings.Steps[StepNumber].Page = SearchName Then
			Return StepNumber;
		EndIf;
	EndDo;
	
	Raise StrReplace(NStr("en='Not found step ""%1"".';ru='Не найдено шаг ""%1"".'"), "%1", SearchName);
EndFunction

// Returns the cancel check box
&AtClient
Function AssistantPageIdleProcessing()
	StepDescription = StepByStepAssistantSettings.Steps[StepByStepAssistantSettings.CurrentStepNumber];
	Action = StepDescription.OnProcessWaiting;
	If IsBlankString(Action) Then
		Return False;
	EndIf;
	
	Notification = New NotifyDescription(Action, ThisObject);
	
	Stop = False;
	ExecuteNotifyProcessing(Notification, Stop);
	ToContinueTo = Not Stop;
	
	If ToContinueTo Then
		AttachIdleHandler("AssistantPageIdleProcessing", StepByStepAssistantSettings.LongOperationWaitingTimeout, True);
	EndIf;
	
	Return ToContinueTo;
EndFunction

&AtClient
Procedure AfterTaskCancellationAndClosingFormConfirmation(Response, ExecuteParameters) Export
	If Response = DialogReturnCode.Abort Then
		CheckBackgroundJobAndCloseFormWithoutConfirmation();
	Else
		AssistantPageIdleProcessing();
	EndIf;
EndProcedure

&AtClient
Procedure CheckBackgroundJobAndCloseFormWithoutConfirmation()
	If Not BackgroundJobImportOnClient(True, False) Then
		StepByStepAssistantSettings.HasJobCancellationConfirmation = True;
		Close();
	EndIf;
EndProcedure

&AtClient
Function BackgroundJobImportOnClient(InterruptIfNotCompleted, ShowDialogBeforeClosing)
	
	DetachIdleHandler("AssistantPageIdleProcessing");
	
	InformationAboutJob = BackgroundJobImportResult(InterruptIfNotCompleted);
	If Not InformationAboutJob.Completed Then
		If ShowDialogBeforeClosing Then
			Handler = New NotifyDescription("AfterTaskCancellationAndClosingFormConfirmation", ThisObject);
			
			If StepByStepAssistantSettings.ProcedureName = "DefineUsagePlacess" Then
				QuestionText = NStr("en='Stop the search of usage places and close the form?';ru='Прервать поиск мест использования и закрыть форму?'");
			ElsIf StepByStepAssistantSettings.ProcedureName = "ReplaceRefs" Then
				QuestionText = NStr("en='Stop items merging and close the form?';ru='Прервать объединение элементов и закрыть форму?'");
			EndIf;
			
			Buttons = New ValueList;
			Buttons.Add(DialogReturnCode.Abort, NStr("en='Break';ru='Прервать'"));
			Buttons.Add(DialogReturnCode.No, NStr("en='Do not interrupt';ru='Не прерывать'"));
			
			ShowQueryBox(Handler, QuestionText, Buttons, , DialogReturnCode.No);
		EndIf;
		Return False;
	EndIf;
	
	If StepByStepAssistantSettings.ProcedureName = "DefineUsagePlacess" Then
		If InformationAboutJob.ErrorInfo = Undefined Then
			Activate();
			AssistantStep("Next");
		Else
			Activate();
			ShowMessageBox(, InformationAboutJob.ErrorInfo);
		EndIf;
	ElsIf StepByStepAssistantSettings.ProcedureName = "ReplaceRefs" Then
		If InformationAboutJob.ErrorInfo = Undefined Then
			If InformationAboutJob.Result = True Then
				// Completely successful - close the form and display an alert.
				ShowUserNotification(,
					GetURL(MainItem),
					EndingMessage(),
					PictureLib.Information32);
				UpdatedList = New Array;
				For Each String IN UsagePlaces Do
					UpdatedList.Add(String.Ref);
				EndDo;
				SuccessfulReplacementAlert(UpdatedList);
				// Close form.
				Close();
			Else
				// Partially successful - output decryption.
				Activate();
				GoToAssistantStep(Items.RepeatMergingStep, True);
			EndIf
		Else
			// Background job failed with error.
			Activate();
			ShowMessageBox(, InformationAboutJob.ErrorInfo);
			GoToAssistantStep(Items.StepSelectMainItem);
		EndIf;
	EndIf;
	
	Return True;
EndFunction

&AtServer
Function BackGroundJobStart(Val ProcedureName)
	// Cancel the previous job.
	BackgroundJobCancel();
	
	// Define start parameters.
	MethodFullName = "SearchAndDeleteDuplicates." + ProcedureName;
	
	If ProcedureName = "DefineUsagePlacess" Then
		
		MethodName = NStr("en='Search and delete duplicates: Define places of use';ru='Поиск и удаление дублей: Определение мест использования'");
		MethodParameters = RefsArrayFromSet(UsagePlaces);
		
	ElsIf ProcedureName = "ReplaceRefs" Then
		
		MethodName = NStr("en='Search and remove duplicates: Merge items';ru='Поиск и удаление дублей: Объединение элементов'");
		SubstitutionsPairs = New Map;
		For Each String IN UsagePlaces Do
			SubstitutionsPairs.Insert(String.Ref, MainItem);
		EndDo;
		
		ReplacementParameters = New Structure;
		ReplacementParameters.Insert("RemovalMethod", CurrentRemovalVariant);
		ReplacementParameters.Insert("EnableBusinessLogic", True);
		
		MethodParameters = New Structure;
		MethodParameters.Insert("SubstitutionsPairs", SubstitutionsPairs);
		MethodParameters.Insert("Parameters", ReplacementParameters);
		
	Else
		
		Return False;
		
	EndIf;
	
	// Start.
	ErrorInfo = Undefined;
	Try
		Task = LongActions.ExecuteInBackground(
			UUID,
			MethodFullName,
			MethodParameters,
			MethodName);
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	If ErrorInfo <> Undefined Then
		StepByStepAssistantSettings.JobCompleted               = True;
		StepByStepAssistantSettings.ErrorInfo             = DetailErrorDescription(ErrorInfo);
		StepByStepAssistantSettings.BackgroundJobID   = Undefined;
		StepByStepAssistantSettings.BackgroundJobResultAddress = Undefined;
		StepByStepAssistantSettings.ProcedureName                   = Undefined;
		Return False;
	EndIf;
	
	StepByStepAssistantSettings.BackgroundJobResultAddress = Task.StorageAddress;
	StepByStepAssistantSettings.BackgroundJobID   = Task.JobID;
	StepByStepAssistantSettings.JobCompleted               = Task.JobCompleted;
	StepByStepAssistantSettings.ProcedureName                   = ProcedureName;
	
	If StepByStepAssistantSettings.JobCompleted Then
		Return False;
	EndIf;
	
	Return True;
EndFunction

&AtServer
Function BackgroundJobImportResult(Val InterruptIfNotCompleted = False)
	If StepByStepAssistantSettings.JobCompleted Then
		StepByStepAssistantSettings.BackgroundJobID = Undefined;
	Else
		Task = BackgroundJobs.FindByUUID(StepByStepAssistantSettings.BackgroundJobID);
		If Task <> Undefined Then
			If Task.ErrorInfo <> Undefined Then
				StepByStepAssistantSettings.ErrorInfo = DetailErrorDescription(Task.ErrorInfo);
			EndIf;
			StepByStepAssistantSettings.JobCompleted = Task.Status <> BackgroundJobState.Active;
			If StepByStepAssistantSettings.JobCompleted Then
				// Current messages of a background job.
				AccumulatedMessages = Task.GetUserMessages(True);
				If AccumulatedMessages <> Undefined Then
					For Each Message IN AccumulatedMessages Do
						Message.Message();
					EndDo;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	Value = Undefined;
	If StepByStepAssistantSettings.JobCompleted Then
		StepByStepAssistantSettings.BackgroundJobID = Undefined;
		If StepByStepAssistantSettings.ErrorInfo = Undefined Then
			Value = GetFromTempStorage(StepByStepAssistantSettings.BackgroundJobResultAddress);
			If StepByStepAssistantSettings.ProcedureName = "DefineUsagePlacess" Then
				FillUsagePlaces(Value);
				Value = Undefined;
			ElsIf StepByStepAssistantSettings.ProcedureName = "ReplaceRefs" Then
				Value = Not FillFailedReplacements(Value);
			EndIf;
		EndIf;
	EndIf;
	
	If InterruptIfNotCompleted AND Not StepByStepAssistantSettings.JobCompleted Then
		BackgroundJobCancel();
	EndIf;
	
	InformationAboutJob = New Structure;
	InformationAboutJob.Insert("Completed",          StepByStepAssistantSettings.JobCompleted);
	InformationAboutJob.Insert("ErrorInfo", StepByStepAssistantSettings.ErrorInfo);
	InformationAboutJob.Insert("Result",          Value);
	
	Return InformationAboutJob;
EndFunction

&AtServer
Procedure BackgroundJobCancel()
	If StepByStepAssistantSettings.BackgroundJobID <> Undefined Then
		LongActions.CancelJobExecution(StepByStepAssistantSettings.BackgroundJobID);
	EndIf;
	StepByStepAssistantSettings.JobCompleted               = False;
	StepByStepAssistantSettings.BackgroundJobResultAddress = Undefined;
	StepByStepAssistantSettings.ErrorInfo             = Undefined;
	StepByStepAssistantSettings.BackgroundJobID   = Undefined;
	StepByStepAssistantSettings.ProcedureName                   = Undefined;
EndProcedure

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
