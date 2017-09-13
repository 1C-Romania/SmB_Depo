// Form is parameterized.
//
// Parameters:
//     RefsSet - Array, ValuesList - items set for analysis.
//                                            It can be a collection of items that have the Ref field.
//

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("OpenByScenario") Then
		Raise NStr("en='Data processor is not intended for direct usage.';ru='Обработка не предназначена для непосредственного использования.'");
	EndIf;
	
	// Transfer parameters to the ReplacedRefs table. 
	// Initialize the TargetItem, ReplaceRefsCommonOwner, ParametersErrorText attributes.
	InitializeReplacedReferences( RefArrayFromList(Parameters.RefSet) );
	If Not IsBlankString(ParametersErrorText) Then
		// A warning will be shown during opening;
		Return;
	EndIf;
	
	PermanentlyDeletionRight = AccessRight("DataAdministration", Metadata);
	EventReplacementNotifications        = DataProcessors.ReplaceAndCombineElements.EventReplacementNotifications();
	CurrentRemovalVariant          = "Mark";
	
	// Initialize the dynamic list on a form - Simulates a selection form.
	MainMetadata = TargetItem.Metadata();
	List.CustomQuery = False;
	List.MainTable = MainMetadata.FullName();
	List.DynamicDataRead = True;
	
	Items.Add("ListRefNew", Type("FormField"), Items.ListItem).DataPath = "List.Ref";
	
	// You can add the code only if one is present.
	If PossibleRefCode(TargetItem, New Map) <> Undefined Then
		NewColumn = Items.Add("ListCodeNew", Type("FormField"), Items.List);
		NewColumn.DataPath = "List.Code";
	EndIf;
	
	Items["ListRefNew"].Title = NStr("en='Description';ru='Description'");
	
	Items.List.ChangeRowOrder = False;
	Items.List.ChangeRowSet  = False;
	
	ReplacedList = New ValueList;
	ReplacedList.LoadValues(ReplaceReferences.Unload().UnloadColumn("Ref"));
	CommonUseClientServer.SetFilterDynamicListItem(
		List,
		"Ref",
		ReplacedList,
		DataCompositionComparisonType.NotInList,
		NStr("en='Do not show replaced';ru='Не показывать заменяемые'"),
		True,
		DataCompositionSettingsItemViewMode.Inaccessible,
		"5bf5cd06-c1fd-4bd3-94b9-4e9803e90fd5");
	
	If ReplaceableLinksCommonOwner <> Undefined Then 
		CommonUseClientServer.SetFilterDynamicListItem(List, "Owner", ReplaceableLinksCommonOwner );
	EndIf;
	
	If ReplaceReferences.Count() > 1 Then
		Items.LabelSelectedType.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Select one of the ""%1"" items the selected values (%2) should be replaced with:';ru='Выберите один из элементов ""%1"", на который следует заменить выбранные значения (%2):'"),
			MainMetadata.Presentation(), ReplaceReferences.Count());
	Else
		Title = NStr("en='Replace item';ru='Замена элемента'");
		Items.LabelSelectedType.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Select one of the ""%1"" items ""%2"" should be replaced with:';ru='Выберите один из элементов ""%1"", на который следует заменить ""%2"":'"),
			MainMetadata.Presentation(), ReplaceReferences[0].Ref);
	EndIf;
	Items.ToolTipSelectTargetItem.Title = NStr("en='Replacement item is not selected.';ru='Элемент для замены не выбран.'");
	
	// Stepped master
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
	SetAssistantInitialPage(Items.StepSelectTargetItem);
	RunAssistant();
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	// Check job.
	If StepByStepAssistantSettings.JobCompleted = False
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
Procedure TargetItemSelectToolTipNavigationRefsDataProcessor(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	
	If URL = "RemovalModeSwitch" Then
		If CurrentRemovalVariant = "Directly" Then
			CurrentRemovalVariant = "Mark" 
		Else
			CurrentRemovalVariant = "Directly" 
		EndIf;
		
		FormTargetItemAndToolTip(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("FormTargetItemAndToolTipDelayed", 0.01, True);
	
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

	ConditionalAppearance.Items.Clear();

EndProcedure

&AtClientAtServerNoContext
Procedure FormTargetItemAndToolTip(Context)
	
	CurrentData = Context.Items.List.CurrentData;
	// Bypass emptiness and groups
	If CurrentData = Undefined Or AttributeValue(CurrentData, "IsFolder", False) Then
		Return;
	EndIf;
	Context.TargetItem = CurrentData.Ref;
	
	Count = Context.ReplaceReferences.Count();
	If Count = 1 Then
		
		If Context.PermanentlyDeletionRight Then
			If Context.CurrentRemovalVariant = "Mark" Then
				ToolTipText = NStr("en='The selected item will be
		|replaced with %1 and <a href = ""DeletionModeSwitch>marked for deletion</a>.';ru='Выбранный элемент будет заменен на ""%1""
		|и <a href = ""ПереключениеРежимаУдаления"">помечен на удаление</a>.'");
			Else
				ToolTipText = NStr("en='The selected item will be
		|replaced with %1 and <a href = ""DeletionModeSwitch>permanently deleted</a>.';ru='Выбранный элемент будет заменен на ""%1""
		|и <a href = ""ПереключениеРежимаУдаления"">удален безвозвратно</a>.'");
			EndIf;
		Else
			ToolTipText = NStr("en='The selected item will be
		|replaced with %1 and marked for deletion.';ru='Выбранный элемент будет
		|заменен на ""%1"" и помечен на удаление.'");
		EndIf;
			
		ToolTipText = StringFunctionsClientServer.SubstituteParametersInString(ToolTipText, Context.TargetItem);
		Context.Items.ToolTipSelectTargetItem.Title = StringFunctionsClientServer.FormattedString(ToolTipText);
		
	Else
		
		If Context.PermanentlyDeletionRight Then
			If Context.CurrentRemovalVariant = "Mark" Then
				ToolTipText = NStr("en='The selected items (%1) will be
		|replaced with %2 and <a href = ""DeletionModeSwitch>marked for deletion</a>.';ru='Выбранные элементы (%1) будут заменены на ""%2""
		|и <a href = ""ПереключениеРежимаУдаления"">помечены на удаление</a>.'");
			Else
				ToolTipText = NStr("en='The selected items (%1) will be
		|replaced with %2 and <a href = ""DeletionModeSwitch>permanently deleted</a>.';ru='Выбранные элементы (%1) будут заменены на ""%2""
		|и <a href = ""ПереключениеРежимаУдаления"">удалены безвозвратно</a>.'");
			EndIf;
		Else
			ToolTipText = NStr("en='The selected items (%1) will be
		|replaced with %2 and marked for deletion.';ru='Выбранные элементы (%1) будут
		|заменены на ""%2"" и помечен на удаление.'");
		EndIf;
			
		ToolTipText = StringFunctionsClientServer.SubstituteParametersInString(ToolTipText, 
			Count, Context.TargetItem);
		Context.Items.ToolTipSelectTargetItem.Title = StringFunctionsClientServer.FormattedString(ToolTipText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FormTargetItemAndToolTipDelayed()
	FormTargetItemAndToolTip(ThisObject);
EndProcedure

&AtClient
Function EndingMessage()
	
	Count = ReplaceReferences.Count();
	If Count = 1 Then
		ResultText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Item ""%1"" is replaced with ""%2""';ru='Элемент ""%1"" заменен на ""%2""'"),
			ReplaceReferences[0].Ref,
			TargetItemResult);
	Else
		ResultText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Items (%1) are replaced with ""%2""';ru='Элементы (%1) заменены на ""%2""'"),
			Count,
			TargetItemResult);
	EndIf;
	
	Return ResultText;
	
EndFunction

&AtClient
Procedure FormLabelFailedReplacements()
	
	Items.ResultFailedReplacements.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Unable to replace items (%1 from %2). IN some places of use, an automatic
		|replacement for %3 can not be executed.';ru='Не удалось заменить элементы (%1 из %2). В некоторых местах использования не может быть произведена
		|автоматическая замена на ""%3""'"),
		FailedReplacements.GetItems().Count(),
		ReplaceReferences.Count(),
		TargetItem);
	
EndProcedure

&AtServer
Function CheckReplaceReferencesPossibility()
	
	Result = "";
	SubstitutionsPairs = New Map;
	For Each String IN ReplaceReferences Do
		SubstitutionsPairs.Insert(String.Ref, TargetItem);
	EndDo;
	
	ReplacementParameters = New Structure("RemovalMethod", CurrentRemovalVariant);
	Return SearchAndDeleteDuplicates.CheckItemsReplacePossibilityRow(SubstitutionsPairs, ReplacementParameters);
	
EndFunction

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
			ErrorString.Cause = NStr("en='Data which processing was not planned is detected.';ru='Обнаружена данные, обработка которых не планировалась.'");
			
		ElsIf ErrorType = "LockError" Then
			ErrorString.Cause = NStr("en='The data is locked by another user.';ru='Данные заблокированы другим пользователем.'");
			
		ElsIf ErrorType = "DataChanged" Then
			ErrorString.Cause = NStr("en='Data is changed by another user.';ru='Данные изменены другим пользователем.'");
			
		ElsIf ErrorType = "RecordingError" Then
			ErrorString.Cause = ResultRow.ErrorText;
			
		ElsIf ErrorType = "ErrorDelete" Then
			ErrorString.Cause = NStr("en='You cannot delete data.';ru='Невозможно удалить данные.'");
			
		Else
			ErrorString.Cause = NStr("en='Unknown error.';ru='Неизвестная ошибка.'");
			
		EndIf;
		
		ErrorString.DetailedReason = ResultRow.ErrorText;
	EndDo; // replacement results
	
	Return RootRows.Count() > 0;
EndFunction

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
	If TypeList.Count()>0 Then
		Notify(EventReplacementNotifications, , ThisObject);
	EndIf;
EndProcedure

// Converts an array, a values list or collection to an array.
//
&AtServerNoContext
Function RefArrayFromList(Val Refs)
	
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

// Returns:
//     Arbitrary - catalog code etc if it exists according to metadata, Undefined - if there is no code.
//
&AtServerNoContext
Function PossibleRefCode(Val Refs, MetadataCache)
	Meta = Refs.Metadata();
	ThereIsCode = MetadataCache[Meta];
	
	If ThereIsCode = Undefined Then
		// Check if there is a code.
		Test = New Structure("CodeLength", 0);
		FillPropertyValues(Test, Meta);
		ThereIsCode = Test.CodeLength > 0;
		
		MetadataCache[Meta] = ThereIsCode;
	EndIf;
	
	Return ?(ThereIsCode, Refs.Code, Undefined);
EndFunction

// Safely receive attribute values.
//
&AtClientAtServerNoContext
Function AttributeValue(Val Data, Val AttributeName, Val ValueWithout = Undefined)

	Sample = New Structure(AttributeName);
	
	FillPropertyValues(Sample, Data);
	If Sample[AttributeName] <> Undefined Then
		// There is a value
		Return Sample[AttributeName];
	EndIf;
	
	// The value in data may be equal to Undefined.
	Sample[AttributeName] = True;
	FillPropertyValues(Sample, Data);
	If Sample[AttributeName] <> True Then
		Return Sample[AttributeName];
	EndIf;
	
	Return ValueWithout;
EndFunction

&AtServer
Procedure InitializeReplacedReferences(Val RefArray)
	
	QuantityRefs = RefArray.Count();
	If QuantityRefs = 0 Then
		ParametersErrorText = NStr("en='No item for replacement is specified.';ru='Не указано ни одного элемента для замены.'");
		Return;
	EndIf;
	
	TargetItem = RefArray[0];
	
	MainMetadata = TargetItem.Metadata();
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
	Query = New Query(
		"SELECT
		|Refs AS Ref
		|" + AdditionalFields + "
		|PLACE
		|ReplacedRefs FROM
		|	" + TableName + "
		|WHERE
		|	Refs IN (&RefsSet)
		|INDEX BY
		|	Owner,
		|	IsFolder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	COUNT(DISTINCT Owner) AS OwnersQuantity,
		|	MIN(Owner)              AS CommonOwner,
		|	MAX(IsFolder)            AS HasFolders,
		|	COUNT(Refs)             AS QuantityRefs
		|FROM
		|	ReplaceReferences
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	TargetTable.Ref
		|FROM
		|	" + TableName + " AS
		|		TargetTable LEFT JOIN ReplaceReferences AS
		|		ReplaceReferences ON TargetTable.Ref =
		|		ReplaceReferences.Ref AND TargetTable.Owner =
		|ReplaceReferences.Owner
		|WHERE ReplaceReferences.Ref IS
		|	NULL AND NOT TargetTable.IiGroup");
		
	If Not HasOwners Then
		Query.Text = StrReplace(Query.Text, "AND TargetTable.Owner = ReplacedRefs.Owner", "");
	EndIf;
	If Not HasFolders Then
		Query.Text = StrReplace(Query.Text, "AND NOT TargetTable.IsFolder", "");
	EndIf;
	Query.SetParameter("RefsSet", RefArray);
	
	Result = Query.ExecuteBatch();
	Conditions = Result[1].Unload()[0];
	If Conditions.HasFolders Then
		ParametersErrorText = NStr("en='One of the replaced items is a group.
		|Groups can not be replaced.';ru='Один из заменяемых элементов является группой.
		|Группы не могут быть заменены.'");
		Return;
	ElsIf Conditions.OwnersQuantity > 1 Then 
		ParametersErrorText = NStr("en='Replaced items have different owners.
		|Such items can not be replaced.';ru='У заменяемых элементов разные владельцы.
		|Такие элементы не могут быть заменены.'");
		Return;
	ElsIf Conditions.QuantityRefs <> QuantityRefs Then
		ParametersErrorText = NStr("en='All replaceable items must be of the same type.';ru='Все заменяемые элементы должны быть одного типа.'");
		Return;
	EndIf;
	
	If Result[2].Unload().Count() = 0 Then
		If QuantityRefs > 1 Then
			ParametersErrorText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There is nothing to replace the selected items (%1) with.';ru='Выбранные элементы (%1) не на что заменить.'"), QuantityRefs);
		Else
			ParametersErrorText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There is nothing to replace selected item ""%1"" with.';ru='Выбранный элемент ""%1"" не на что заменить.'"), CommonUse.SubjectString(TargetItem));
		EndIf;
		Return;
	EndIf;
	
	ReplaceableLinksCommonOwner = ?(HasOwners, Conditions.CommonOwner, Undefined);
	For Each Item IN RefArray Do
		ReplaceReferences.Add().Ref = Item;
	EndDo;
	
EndProcedure

&AtServer
Procedure InitializeAssistantScript()
	
	// 0. Select the main item.
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Visible = False;
	ButtonsAssistant.Next.Title = NStr("en='Replace >';ru='Заменить >'");
	ButtonsAssistant.Next.ToolTip = NStr("en='Start replacing items';ru='Начать замену элементов'");
	ButtonsAssistant.Cancel.Title = NStr("en='Cancel';ru='Отменить'");
	ButtonsAssistant.Cancel.ToolTip = NStr("en='Refuse to replace items';ru='Отказаться от замены элементов'");
	
	AddAssistantStep(Items.StepSelectTargetItem, 
		AssistantStepAction("OnActivating",         "StepSelectTargetItemOnActivating",
		AssistantStepAction("BeforeNextAction",  "StepSelectTargetItemBeforeNextAction",
		AssistantStepAction("BeforeCancelAction", "StepSelectTargetItemBeforeCancelAction"))), 
		ButtonsAssistant);
	
	// 1. Waiting for a process
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Visible = False;
	ButtonsAssistant.Next.Visible = False;
	ButtonsAssistant.Cancel.Title = NStr("en='Abort';ru='Прервать'");
	ButtonsAssistant.Cancel.ToolTip = NStr("en='Stop item replacement';ru='Прервать замену элементов'");
	
	AddAssistantStep(Items.StepReplacement, 
		AssistantStepAction("OnActivating",         "StepReplacementOnActivating",
		AssistantStepAction("BeforeCancelAction", "StepReplacementBeforeCancelAction",
		AssistantStepAction("OnProcessWaiting", "StepReplacementOnProcessWaiting"))), 
		ButtonsAssistant);
	
	// 2. Successful merging
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Visible = False;
	ButtonsAssistant.Next.Visible = False;
	ButtonsAssistant.Next.DefaultButton = False;
	ButtonsAssistant.Cancel.DefaultButton = True;
	ButtonsAssistant.Cancel.Title = NStr("en='Close';ru='Закрыть'");
	ButtonsAssistant.Cancel.ToolTip = NStr("en='Close results of item replacement';ru='Закрыть результаты замены элементов'");
	
	AddAssistantStep(Items.SuccessfulCompletionStep, 
		AssistantStepAction("OnActivating",         "StepSuccessfulCompletionOnActivating",
		AssistantStepAction("BeforeCancelAction", "StepSuccessfulCompletionBeforeCancelAction")), 
		ButtonsAssistant);
	
	// 3. Errors of reference replacements
	ButtonsAssistant = ButtonsAssistant();
	ButtonsAssistant.Back.Title = NStr("en='< Back';ru='< Back'");
	ButtonsAssistant.Back.ToolTip = NStr("en='Return to target item selection';ru='Вернутся к выбору целевого элемента'");
	ButtonsAssistant.Next.Title = NStr("en='Repeat replacement >';ru='Повторить замену >'");
	ButtonsAssistant.Next.ToolTip = NStr("en='Repeat item replacement';ru='Повторить замену элементов'");
	ButtonsAssistant.Cancel.Title = NStr("en='Close';ru='Закрыть'");
	ButtonsAssistant.Cancel.ToolTip = NStr("en='Close results of item replacement';ru='Закрыть результаты замены элементов'");
	
	AddAssistantStep(Items.StepRepeatReplacement,
		AssistantStepAction("OnActivating",         "StepRepeatReplacementOnActivating",
		AssistantStepAction("BeforeNextAction",  "StepRepeatReplacementBeforeNextAction",
		AssistantStepAction("BeforeBackAction",  "StepRepeatReplacementBeforeBackAction",
		AssistantStepAction("BeforeCancelAction", "StepRepeatReplacementBeforeCancelAction")))), 
		ButtonsAssistant);
EndProcedure

&AtClient
Procedure StepSelectTargetItemOnActivating(Val Page, Val AdditionalParameters) Export
	
	FormTargetItemAndToolTip(ThisObject);
	
EndProcedure

&AtClient
Procedure StepSelectTargetItemBeforeNextAction(Val StepParameters, Val AdditionalParameters) Export
	// Check for improper replacements.
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
		
	ElsIf ReplaceReferences.Count() = 1 AND CurrentData.Ref = ReplaceReferences.Get(0).Ref Then
		ShowMessageBox( , NStr("en='An item cannot be replaced with itself.';ru='Нельзя заменять элемент сам на себя.'"));
		Return;
		
	ElsIf AttributeValue(CurrentData, "IsFolder", False) Then
		ShowMessageBox( , NStr("en='Cannot replace item with group.';ru='Нельзя заменять элемент на группу.'"));
		Return;
	EndIf;
	
	CurrentOwner = AttributeValue(CurrentData, "Owner");
	If CurrentOwner <> ReplaceableLinksCommonOwner Then
		ShowMessageBox( , StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='You can not replace it with the object subordinate to another user.
		|The selected item has %1 as an owner, and the replaced item has %2 as an owner.';ru='Нельзя заменять на элемент, подчиненный другому владельцу.
		|У выбранного элемента владелец ""%1"", а у заменяемого - ""%2"".'"),
			CurrentOwner, ReplaceableLinksCommonOwner
		));
		Return;
		
	ElsIf Not AttributeValue(CurrentData, "DeletionMark", False) Then
		// An additional check by applied data is required.
		CheckAppliedAreaReplacementAdmissibility(StepParameters);
		Return;
		
	EndIf;
	
	// An attempt to replace with an item marked for deletion.
	Text = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Item %1 is marked for deletion. Continue?';ru='Элемент %1 помечен на удаление. Продолжить?'"),
		CurrentData.Ref
	);
	
	Description = New NotifyDescription("TargetItemSelectionConfirmation", ThisObject, New Structure);
	Description.AdditionalParameters.Insert("StepParameters", StepParameters);
	ShowQueryBox(Description, Text, QuestionDialogMode.YesNo);
EndProcedure

&AtClient
Procedure StepSelectTargetItemBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	Close();
EndProcedure

&AtClient
Procedure StepReplacementOnActivating(Val Page, Val AdditionalParameters) Export
	// Start a long processor by replacement.
	BackGroundJobStart();
EndProcedure

&AtClient
Procedure StepReplacementOnProcessWaiting(Stop, Val AdditionalParameters) Export
	
	If BackgroundJobImportOnClient(False, False) Then
		Stop = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure StepReplacementBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	CheckBackgroundJobAndCloseFormWithoutConfirmation();
EndProcedure

&AtClient
Procedure StepSuccessfulCompletionOnActivating(Val Page, Val AdditionalParameters) Export
	
	// Update label 
	Items.ReplacementResult.Title = EndingMessage();
	
	// Notify about successful replacement.
	UpdatedList = New Array;
	UpdatedList.Add(TargetItem);
	For Each String IN ReplaceReferences Do
		UpdatedList.Add(String.Ref);
	EndDo;
	SuccessfulReplacementAlert(UpdatedList);
	
EndProcedure

&AtClient
Procedure StepSuccessfulCompletionBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	Close();
EndProcedure

&AtClient
Procedure StepRepeatReplacementOnActivating(Val Page, Val AdditionalParameters) Export
	// Update failures quantity.
	FormLabelFailedReplacements();
	
	// Alert if a partial replacement was successful.
	UpdatedList = DeleteFromReplacedProcessed();	// Remove from the list at the same time
	UpdatedList.Add(TargetItem);
	SuccessfulReplacementAlert(UpdatedList);
EndProcedure

&AtClient
Procedure StepRepeatReplacementBeforeNextAction(Val StepParameters, Val AdditionalParameters) Export
	// Repeat replacement
	GoToAssistantStep(Items.StepReplacement, True);
EndProcedure

&AtClient
Procedure StepRepeatReplacementBeforeBackAction(Val StepParameters, Val AdditionalParameters) Export
	GoToAssistantStep(Items.StepSelectTargetItem, True);
EndProcedure

&AtClient
Procedure StepRepeatReplacementBeforeCancelAction(Val StepParameters, Val AdditionalParameters) Export
	Close();
EndProcedure

// Returns the list of successfully replaced references that are missing in FailedReplacements.
&AtClient
Function DeleteFromReplacedProcessed()
	Result = New Array;
	
	Failed = New Map;
	For Each String IN FailedReplacements.GetItems() Do
		Failed.Insert(String.Ref, True);
	EndDo;
	
	IndexOf = ReplaceReferences.Count() - 1;
	While IndexOf > 0 Do
		Refs = ReplaceReferences[IndexOf].Ref;
		If Refs<>TargetItem AND Failed[Refs] = Undefined Then
			ReplaceReferences.Delete(IndexOf);
			Result.Add(Refs);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Procedure TargetItemSelectionConfirmation(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	// Additional check by the applied data.
	CheckAppliedAreaReplacementAdmissibility(AdditionalParameters.StepParameters);
EndProcedure

&AtClient
Procedure CheckAppliedAreaReplacementAdmissibility(Val StepParameters)
	
	// Check the possibility for replacement from the applied point of view.
	ErrorText = CheckReplaceReferencesPossibility();
	
	If IsBlankString(ErrorText) Then
		// All replacements are allowed
		AssistantStepEnd(StepParameters);
		Return;
	EndIf;
	
	WarningParameters = New Structure;
	WarningParameters.Insert("Title", NStr("en='You cannot replace items';ru='Невозможно заменить элементы'"));
	WarningParameters.Insert("MessageText", ErrorText);
	OpenForm("DataProcessor.ReplaceAndCombineElements.Form.MultilineWarning", WarningParameters, ThisObject);
	
EndProcedure

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
//                                         <Page> - FormGroup - group-page that is being activated.
//                                         <AdditionalParameters> - Undefined
//
//          * BeforeNextAction  - String - Optional name of a procedure that will
//                                            be executed after clicking the Next button before going to the next page. The procedure will
//                                            be called with two parameters:
//                                              <StepParameters> - service attribute. If a chain
//                                                                of modeless calls is successfully
//                                                                ended, the last procedure-handler should execute a call.
//                                                                AssistantStepEnd(StepParameter) confirming an action.
//                                              <AdditionalParameters> - Undefined
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
	StepDescription.Insert("Page", Page.Name);
	
	// Set actions
	FillPropertyValues(StepDescription, Actions);
	
	// Buttons description registration.
	For Each KeyAndValue IN Buttons Do
		ButtonName = KeyAndValue.Key;
		ButtonDescription = KeyAndValue.Value;
		// Filling of secondary properties.
		If Not ButtonDescription.Visible Then
			ButtonDescription.Enabled = False;
			ButtonDescription.DefaultButton = False;
		Else
			If Not ValueIsFilled(ButtonDescription.ToolTip) Then
				ButtonDescription.ToolTip = ButtonDescription.Title;
			EndIf;
		EndIf;
		// Registration with the Button prefix.
		StepDescription.Insert("Button" + ButtonName, ButtonDescription);
	EndDo;

	StepByStepAssistantSettings.Steps.Add(StepDescription);
EndProcedure

// Helper formation of a structure describing the action.
//
// Parameters:
//     ID    - String - Action identifier, see description of the AddMasterStep method.
//     HandlerName   - String - Name of the procedure, see description of the AddMasterStep method.
//     ServiceData  - Structure - Accumulates values.
//
// Returns:
//    Structure - Service data with added fields.
//
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
//
&AtClient
Procedure RunAssistant()
	If StepByStepAssistantSettings.StartPage = Undefined Then
		Raise NStr("en='Before you run this wizard, set the home page.';ru='Перед запуском мастера должна быть установлена начальная страница.'");
		
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
						Text = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en='An error occurred when creating event handler %1 for page %2, procedure %3 is not defined';ru='Ошибка создания обработчика события %1 для страницы %2, не определена процедура %3'"),
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
		Raise NStr("en='Incorrect wizard step command';ru='Некорректная команда шага помощника'");
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
		Error = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Step of wizard %1 is not found';ru='Не найден шаг помощника %1'"),
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
		Raise NStr("en='Attempting to go over the last wizard step';ru='Попытка выхода за последний шаг мастера'");
		
	ElsIf StepParameters = -1 AND NextStep < 0 Then
		// You are trying to take a step outside back.
		Raise NStr("en='Attempting to go back from the first wizard step';ru='Попытка выхода назад из первого шага мастера'");
		
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
	
	Raise StrReplace(NStr("en='Step ""%1"" is not found.';ru='Не найдено шаг ""%1"".'"), "%1", SearchName);
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
			Handler   = New NotifyDescription("AfterTaskCancellationAndClosingFormConfirmation", ThisObject);
			QuestionText = NStr("en='Stop items replacement and close the form?';ru='Прервать замену элементов и закрыть форму?'");
			
			Buttons = New ValueList;
			Buttons.Add(DialogReturnCode.Abort, NStr("en='Abort';ru='Прервать'"));
			Buttons.Add(DialogReturnCode.No, NStr("en='Do not interrupt';ru='Не прерывать'"));
			
			ShowQueryBox(Handler, QuestionText, Buttons, , DialogReturnCode.No);
		EndIf;
		Return False;
	EndIf;
	
	If InformationAboutJob.ErrorInfo = Undefined Then
		If InformationAboutJob.Result = True Then
			// Completely successful - close the form and display an alert.
			ShowUserNotification(,
				GetURL(TargetItem),
				EndingMessage(),
				PictureLib.Information32);
			UpdatedList = New Array;
			For Each String IN ReplaceReferences Do
				UpdatedList.Add(String.Ref);
			EndDo;
			SuccessfulReplacementAlert(UpdatedList);
			// Close form.
			Close();
		Else
			// Partially successful - output decryption.
			GoToAssistantStep(Items.StepRepeatReplacement, True);
			Activate();
		EndIf
	Else
		// Background job is complete with an error.
		ShowMessageBox(, InformationAboutJob.ErrorInfo);
		GoToAssistantStep(Items.StepSelectTargetItem);
		Activate();
	EndIf;
	
	Return True;
EndFunction

&AtServer
Function BackGroundJobStart()
	// Cancel the previous job.
	BackgroundJobCancel();
	
	// Define start parameters.
	TargetItemResult = TargetItem;
	
	SubstitutionsPairs = New Map;
	For Each String IN ReplaceReferences Do
		SubstitutionsPairs.Insert(String.Ref, TargetItem);
	EndDo;
	
	ReplacementParameters = New Structure;
	ReplacementParameters.Insert("RemovalMethod", CurrentRemovalVariant);
	ReplacementParameters.Insert("EnableBusinessLogic", True);
	
	MethodParameters = New Structure;
	MethodParameters.Insert("SubstitutionsPairs", SubstitutionsPairs);
	MethodParameters.Insert("Parameters", ReplacementParameters);
	
	// Start.
	ErrorInfo = Undefined;
	Try
		Task = LongActions.ExecuteInBackground(
			UUID,
			"SearchAndDeleteDuplicates.ReplaceRefs",
			MethodParameters,
			NStr("en='Search and delete duplicates: Reference replacement';ru='Поиск и удаление дублей: Замена ссылок'"));
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	If ErrorInfo <> Undefined Then
		StepByStepAssistantSettings.JobCompleted               = True;
		StepByStepAssistantSettings.ErrorInfo             = DetailErrorDescription(ErrorInfo);
		StepByStepAssistantSettings.BackgroundJobID   = Undefined;
		StepByStepAssistantSettings.BackgroundJobResultAddress = Undefined;
		Return False;
	EndIf;
	
	StepByStepAssistantSettings.BackgroundJobResultAddress = Task.StorageAddress;
	StepByStepAssistantSettings.BackgroundJobID   = Task.JobID;
	StepByStepAssistantSettings.JobCompleted               = Task.JobCompleted;
	
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
			Value = Not FillFailedReplacements(Value);
		EndIf;
	ElsIf InterruptIfNotCompleted Then
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
EndProcedure

#EndRegion
