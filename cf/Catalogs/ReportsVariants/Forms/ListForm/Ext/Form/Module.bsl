#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Recursive = True;
	
	ValueTree = ReportsVariantsReUse.CurrentUserSubsystems().Copy();
	SubsystemTreeFillInFullView(ValueTree.Rows);
	ValueToFormAttribute(ValueTree, "SubsystemsTree");
	
	TreeSubsystemsCurrentRow = -1;
	Items.SubsystemsTree.CurrentRow = 0;
	If Parameters.ChoiceMode = True Then
		FormActionMode = "Choice";
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	ElsIf Parameters.Property("SectionRef") Or Parameters.Property("SectionRef") Then
		FormActionMode = "AllReportsSection";
		ArrayOfBypass = New Array;
		ArrayOfBypass.Add(SubsystemsTree.GetItems()[0]);
		While ArrayOfBypass.Count() > 0 Do
			ParentRows = ArrayOfBypass[0].GetItems();
			ArrayOfBypass.Delete(0);
			For Each TreeRow IN ParentRows Do
				If TreeRow.Ref = Parameters.SectionRef Then
					Items.SubsystemsTree.CurrentRow = TreeRow.GetID();
					ArrayOfBypass.Clear();
					Break;
				Else
					ArrayOfBypass.Add(TreeRow);
				EndIf;
			EndDo;
		EndDo;
	Else
		FormActionMode = "List";
		CommonUseClientServer.SetFormItemProperty(
			Items,
			"Change",
			"Representation",
			ButtonRepresentation.PictureAndText);
		CommonUseClientServer.SetFormItemProperty(
			Items,
			"PlaceInSections",
			"OnlyInAllActions",
			False);
	EndIf;
	
	GlobalSettings = ReportsVariants.GlobalSettings();
	Items.SearchString.InputHint = GlobalSettings.Search.InputHint;
	
	WindowOptionsKey = FormActionMode;
	PurposeUseKey = FormActionMode;
	
	SetListPropertyByFormParameter("ChoiceMode");
	SetListPropertyByFormParameter("ChoiceFoldersAndItems");
	SetListPropertyByFormParameter("Multiselect");
	SetListPropertyByFormParameter("CurrentRow");
	
	If Parameters.ChoiceMode Then
		CommonUseClientServer.SetFormItemProperty(
			Items,
			"SELECT",
			"DefaultButton",
			True);
	Else
		CommonUseClientServer.SetFormItemProperty(
			Items,
			"SELECT",
			"Visible",
			False);
	EndIf;
	
	FullRightsForVariants = ReportsVariants.FullRightsForVariants();
	If Not FullRightsForVariants Then
		CommonUseClientServer.SetFormItemProperty(
			Items,
			"SelectTypeOfReport",
			"Visible",
			False);
	EndIf;
	
	ChoiceList = Items.SelectTypeOfReport.ChoiceList;
	ChoiceList.Add(1, NStr("en='Internal and Additional';ru='Внутренние и Дополнительные'"));
	ChoiceList.Add(Enums.ReportsTypes.Internal, NStr("en='Internal';ru='Внутренние'"));
	ChoiceList.Add(Enums.ReportsTypes.Additional, NStr("en='Additional';ru='Дополнительные'"));
	ChoiceList.Add(Enums.ReportsTypes.External, NStr("en='External';ru='Внешние'"));
	
	Parameters.Property("SearchString", SearchString);
	If Parameters.Filter.Property("ReportType", SelectTypeOfReport) Then
		Parameters.Filter.Delete("ReportType");
	EndIf;
	If Parameters.Property("VariantsOnly") Then
		If Parameters.VariantsOnly Then
			CommonUseClientServer.SetFilterDynamicListItem(
				List,
				"VariantKey",
				"",
				DataCompositionComparisonType.NotEqual,
				,
				,
				DataCompositionSettingsItemViewMode.Normal);
		EndIf;
	EndIf;
	
	PersonalListSettings = CommonUse.CommonSettingsStorageImport(
		ReportsVariantsClientServer.SubsystemFullName(),
		"Catalog.ReportsVariants.ListForm");
	If PersonalListSettings <> Undefined Then
		Items.SearchString.ChoiceList.LoadValues(PersonalListSettings.SearchStringChoiceList);
	EndIf;
	
	List.Parameters.SetParameterValue("TypeInternal",     Enums.ReportsTypes.Internal);
	List.Parameters.SetParameterValue("TypeOptional", Enums.ReportsTypes.Additional);
	List.Parameters.SetParameterValue("DisabledApplicationOptions", ReportsVariantsReUse.DisabledApplicationOptions());
	//Ryabko Vitaly 2016-12-06 Task Задача №360:Локализация вариантов отчетов (
	UserLanguge = InfoBaseUsers.CurrentUser().Language;
	If NOT UserLanguge = Undefined Then
		List.Parameters.SetParameterValue("LangKey", InfoBaseUsers.CurrentUser().Language.LanguageCode);
	EndIf;
	//Ryabko Vitaly 2016-12-06 Task Задача №360:Локализация вариантов отчетов )
	CurrentItem = Items.List;
	
	// Custom selection by deletion mark.
	CommonUseClientServer.SetFilterDynamicListItem(
		List, "DeletionMark", False, DataCompositionComparisonType.Equal, , ,
		DataCompositionSettingsItemViewMode.Normal);
	
	UpdateListContent("OnCreateAtServer");
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If FormActionMode = "AllReportsSection" OR FormActionMode = "Choice" Then
		Items.SubsystemsTree.Expand(TreeSubsystemsCurrentRow, True);
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = ReportsVariantsClientServer.EventNameOptionChanging() Then
		TreeSubsystemsCurrentRow = -1;
		AttachIdleHandler("TreeHandlerSubsystemsIncreaseRows", 0.1, True);
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FilterReportTypeOnChange(Item)
	UpdateListContent();
EndProcedure

&AtClient
Procedure FilterReportTypeClearing(Item, StandardProcessing)
	StandardProcessing = False;
	SelectTypeOfReport = Undefined;
	UpdateListContent();
EndProcedure

&AtClient
Procedure SearchStringOnChange(Item)
	UpdateListContent("SearchStringOnChange");
EndProcedure

&AtClient
Procedure UncludingSubordinatesOnChange(Item)
	TreeSubsystemsCurrentRow = -1;
	AttachIdleHandler("TreeHandlerSubsystemsIncreaseRows", 0.1, True);
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersSubsystemsTree

&AtClient
Procedure TreeSubsystemsBeforeRowChange(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure TreeSubsystemsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure TreeSubsystemsBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure SubsystemsTreeOnActivateRow(Item)
	AttachIdleHandler("TreeHandlerSubsystemsIncreaseRows", 0.1, True);
EndProcedure

&AtClient
Procedure SubsystemsTreeDrag(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
	
	If String = Undefined Then
		Return;
	EndIf;
	
	ArrangementParameters = New Structure("Variants, Action, Receiver, Source"); //OptionsArray, Total, Presentation
	ArrangementParameters.Variants = New Structure("Array, Total, Presentation");
	ArrangementParameters.Variants.Array = DragParameters.Value;
	ArrangementParameters.Variants.Total  = DragParameters.Value.Count();
	
	If ArrangementParameters.Variants.Total = 0 Then
		Return;
	EndIf;
	
	RowReceiver = SubsystemsTree.FindByID(String);
	If RowReceiver = Undefined OR RowReceiver.Priority = "" Then
		Return;
	EndIf;
	
	ArrangementParameters.Receiver = New Structure("Ref, FullPresentation, Identifier");
	FillPropertyValues(ArrangementParameters.Receiver, RowReceiver);
	ArrangementParameters.Receiver.ID = RowReceiver.GetID();
	
	RowSource = Items.SubsystemsTree.CurrentData;
	ArrangementParameters.Source = New Structure("Ref, FullPresentation, Identifier");
	If RowSource = Undefined OR RowSource.Priority = "" Then
		ArrangementParameters.Action = "Copy";
	Else
		FillPropertyValues(ArrangementParameters.Source, RowSource);
		ArrangementParameters.Source.ID = RowSource.GetID();
		If DragParameters.Action = DragAction.Copy Then
			ArrangementParameters.Action = "Copy";
		Else
			ArrangementParameters.Action = "Move";
		EndIf;
	EndIf;
	
	If ArrangementParameters.Source.Ref = ArrangementParameters.Receiver.Ref Then
		ShowMessageBox(, NStr("en='The selected report variants are already in this section.';ru='Выбранные варианты отчетов уже в данном разделе.'"));
		Return;
	EndIf;
	
	If ArrangementParameters.Variants.Total = 1 Then
		If ArrangementParameters.Action = "Copy" Then
			QuestionTemplate = NStr("en='Place ""%1"" to ""%4""?';ru='Разместить ""%1"" в ""%4""?'");
		Else
			QuestionTemplate = NStr("en='Move ""%1"" from ""%3"" to ""%4""?';ru='Переместить ""%1"" из ""%3"" в ""%4""?'");
		EndIf;
		ArrangementParameters.Variants.Presentation = String(ArrangementParameters.Variants.Array[0]);
	Else
		ArrangementParameters.Variants.Presentation = "";
		For Each VariantRef IN ArrangementParameters.Variants.Array Do
			ArrangementParameters.Variants.Presentation = ArrangementParameters.Variants.Presentation
			+ ?(ArrangementParameters.Variants.Presentation = "", "", ", ")
			+ String(VariantRef);
			If StrLen(ArrangementParameters.Variants.Presentation) > 23 Then
				ArrangementParameters.Variants.Presentation = Left(ArrangementParameters.Variants.Presentation, 20) + "...";
				Break;
			EndIf;
		EndDo;
		If ArrangementParameters.Action = "Copy" Then
			QuestionTemplate = NStr("en='Place report variants ""%1"" (%2 pcs.) in ""%4""?';ru='Разместить варианты отчетов ""%1"" (%2 шт.) в ""%4""?'");
		Else
			QuestionTemplate = NStr("en='Move report variants ""%1"" (%2 pcs.) from ""%3"" to ""%4""?';ru='Переместить варианты отчетов ""%1"" (%2 шт.) из ""%3"" в ""%4""?'");
		EndIf;
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
		QuestionTemplate,
		ArrangementParameters.Variants.Presentation,
		Format(ArrangementParameters.Variants.Total, "NG=0"),
		ArrangementParameters.Source.FullPresentation,
		ArrangementParameters.Receiver.FullPresentation
	);
	
	Handler = New NotifyDescription("SubsystemTreeEndDrag", ThisObject, ArrangementParameters);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	If FormActionMode = "AllReportsSection" Then
		StandardProcessing = False;
		ReportsVariantsClient.OpenReportOption(ThisObject);
	ElsIf FormActionMode = "List" Then
		StandardProcessing = False;
		ReportsVariantsClient.ShowReportSettings(SelectedRow);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RunSearch(Command)
	UpdateListContent();
EndProcedure

&AtClient
Procedure Change(Command)
	ReportsVariantsClient.ShowReportSettings(Items.List.CurrentRow);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SubsystemTreeFillInFullView(RowsSet, ParentView = "")
	For Each TreeRow IN RowsSet Do
		If IsBlankString(TreeRow.Name) Then
			TreeRow.FullPresentation = "";
		ElsIf IsBlankString(ParentView) Then
			TreeRow.FullPresentation = TreeRow.Presentation;
		Else
			TreeRow.FullPresentation = ParentView + "." + TreeRow.Presentation;
		EndIf;
		SubsystemTreeFillInFullView(TreeRow.Rows, TreeRow.FullPresentation);
	EndDo;
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	Instruction = ReportsVariants.ConditionalDesignInstruction();
	Instruction.Fields = "Definition";
	Instruction.Filters.Insert("List.Definition", DataCompositionComparisonType.Filled);
	Instruction.Appearance.Insert("TextColor", StyleColors.ExplanationText);
	ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
EndProcedure

&AtClient
Procedure SubsystemTreeEndDrag(Response, ArrangementParameters) Export
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ExecutionResult = PlaceOptionsInSubsystem(ArrangementParameters);
	
	ReportsVariantsClient.OpenFormsRefresh();
	
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, ExecutionResult);
	
EndProcedure

&AtServer
Procedure SetListPropertyByFormParameter(Key)
	
	If Parameters.Property(Key) AND ValueIsFilled(Parameters[Key]) Then
		Items.List[Key] = Parameters[Key];
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateListContent(Val Event = "")
	PersonalSettingsChanged = False;
	If ValueIsFilled(SearchString) Then
		ChoiceList = Items.SearchString.ChoiceList;
		ItemOfList = ChoiceList.FindByValue(SearchString);
		If ItemOfList = Undefined Then
			ChoiceList.Insert(0, SearchString);
			PersonalSettingsChanged = True;
			If ChoiceList.Count() > 10 Then
				ChoiceList.Delete(10);
			EndIf;
		Else
			IndexOf = ChoiceList.IndexOf(ItemOfList);
			If IndexOf <> 0 Then
				ChoiceList.Move(IndexOf, -IndexOf);
				PersonalSettingsChanged = True;
			EndIf;
		EndIf;
		CurrentItem = Items.SearchString;
	EndIf;
	
	If Event = "SearchStringOnChange" AND PersonalSettingsChanged Then
		PersonalListSettings = New Structure("SearchStringChoiceList");
		PersonalListSettings.SearchStringChoiceList = Items.SearchString.ChoiceList.UnloadValues();
		CommonUse.CommonSettingsStorageSave(
			ReportsVariantsClientServer.SubsystemFullName(),
			"Catalog.ReportsVariants.ListForm",
			PersonalListSettings);
	EndIf;
	
	TreeSubsystemsCurrentRow = Items.SubsystemsTree.CurrentRow;
	
	TreeRow = SubsystemsTree.FindByID(TreeSubsystemsCurrentRow);
	If TreeRow = Undefined Then
		Return;
	EndIf;
	
	AllSubsystems = Not ValueIsFilled(TreeRow.FullName);
	
	SearchParameters = New Structure;
	If ValueIsFilled(SearchString) Then
		SearchParameters.Insert("SearchString", SearchString);
		Items.List.InitialTreeView = InitialTreeView.ExpandAllLevels;
	Else
		Items.List.InitialTreeView = InitialTreeView.NoExpand;
	EndIf;
	If Not AllSubsystems Then
		SubsystemArray = New Array;
		SubsystemArray.Add(TreeRow.Ref);
		If Recursive Then
			AddRecursive(SubsystemArray, TreeRow.GetItems());
		EndIf;
		SearchParameters.Insert("Subsystems", SubsystemArray);
	EndIf;
	If ValueIsFilled(SelectTypeOfReport) Then
		ReportTypeArray = New Array;
		If SelectTypeOfReport = 1 Then
			ReportTypeArray.Add(Enums.ReportsTypes.Internal);
			ReportTypeArray.Add(Enums.ReportsTypes.Additional);
		Else
			ReportTypeArray.Add(SelectTypeOfReport);
		EndIf;
		SearchParameters.Insert("ReportsTypes", ReportTypeArray);
	EndIf;
	
	SearchResult = ReportsVariants.FindReferences(SearchParameters);
	VariantsOfUser = ?(SearchResult = Undefined, Null, SearchResult.Refs);
	List.Parameters.SetParameterValue("VariantsOfUser", VariantsOfUser);
	
EndProcedure

&AtClient
Procedure TreeHandlerSubsystemsIncreaseRows()
	If TreeSubsystemsCurrentRow <> Items.SubsystemsTree.CurrentRow Then
		UpdateListContent();
	EndIf;
EndProcedure

&AtServer
Procedure AddRecursive(SubsystemArray, TreeRowsCollection)
	For Each TreeRow IN TreeRowsCollection Do
		SubsystemArray.Add(TreeRow.Ref);
		AddRecursive(SubsystemArray, TreeRow.GetItems());
	EndDo;
EndProcedure

&AtServer
Procedure SubsystemTreeAddPropertyToArray(TreeLinesArray, PropertyName, RefArray)
	For Each TreeRow IN TreeLinesArray Do
		RefArray.Add(TreeRow[PropertyName]);
		SubsystemTreeAddPropertyToArray(TreeRow.GetItems(), PropertyName, RefArray);
	EndDo;
EndProcedure

&AtServer
Function PlaceOptionsInSubsystem(ArrangementParameters)
	ExcludedSubsystems = New Array;
	If ArrangementParameters.Action = "Move" Then
		RowSource = SubsystemsTree.FindByID(ArrangementParameters.Source.ID);
		ExcludedSubsystems.Add(RowSource.Ref);
		SubsystemTreeAddPropertyToArray(RowSource.GetItems(), "Ref", ExcludedSubsystems);
	EndIf;
	
	Placed = 0;
	BeginTransaction();
	ArrangedAlready = "";
	CannotBeArranged = "";
	For Each VariantRef IN ArrangementParameters.Variants.Array Do
		If VariantRef.ReportType = Enums.ReportsTypes.External Then
			CannotBeArranged = ?(CannotBeArranged = "", "", CannotBeArranged + Chars.LF)
				+ "  "
				+ String(VariantRef)
				+ " ("
				+ NStr("en='external';ru='Внешний'")
				+ ")";
			Continue;
		ElsIf VariantRef.DeletionMark Then
			CannotBeArranged = ?(CannotBeArranged = "", "", CannotBeArranged + Chars.LF)
				+ "  "
				+ String(VariantRef)
				+ " ("
				+ NStr("en='Marked for deletion';ru='Помеченные на удаление'")
				+ ")";
			Continue;
		EndIf;
		
		HasChanges = False;
		VariantObject = VariantRef.GetObject();
		
		RowReceiver = VariantObject.Placement.Find(ArrangementParameters.Receiver.Ref, "Subsystem");
		If RowReceiver = Undefined Then
			RowReceiver = VariantObject.Placement.Add();
			RowReceiver.Subsystem = ArrangementParameters.Receiver.Ref;
		EndIf;
		
		// Delete a string from the original subsystem.
		// To exclude the predefined variant from the susbsystem, you have
		// to clear its check box.
		If ArrangementParameters.Action = "Move" Then
			For Each ExcludedSubsystem IN ExcludedSubsystems Do
				RowSource = VariantObject.Placement.Find(ExcludedSubsystem, "Subsystem");
				If RowSource <> Undefined Then
					If RowSource.Use Then
						RowSource.Use = False;
						If Not HasChanges Then
							FillPropertyValues(RowReceiver, RowSource, "Important, SeeAlso");
							HasChanges = True;
						EndIf;
					EndIf;
					RowSource.Important  = False;
					RowSource.SeeAlso = False;
				ElsIf Not VariantObject.User Then
					RowSource = VariantObject.Placement.Add();
					RowSource.Subsystem = ExcludedSubsystem;
					HasChanges = True;
				EndIf;
			EndDo;
		EndIf;
		
		// Register a string in acceptor subsystem.
		If Not RowReceiver.Use Then
			HasChanges = True;
			RowReceiver.Use = True;
		EndIf;
		
		If HasChanges Then
			Placed = Placed + 1;
			VariantObject.Write();
		Else
			ArrangedAlready = ?(ArrangedAlready = "", "", ArrangedAlready + Chars.LF)
				+ "  "
				+ String(VariantRef);
		EndIf;
	EndDo;
	CommitTransaction();
	
	ExecutionResult = StandardSubsystemsClientServer.NewExecutionResult();
	If ArrangementParameters.Variants.Total = Placed Then
		OutputNotification = ExecutionResult.OutputNotification;
		OutputNotification.Use = True;
		If ArrangementParameters.Variants.Total = 1 Then
			If ArrangementParameters.Action = "Move" Then
				Pattern = NStr("en='Successfully transferred to %1"".';ru='Успешно перемещены в ""%1"".'");
			Else
				Pattern = NStr("en='Successfully placed in %1"".';ru='Успешно размещены в ""%1"".'");
			EndIf;
			OutputNotification.Title = StringFunctionsClientServer.SubstituteParametersInString(
				Pattern,
				ArrangementParameters.Receiver.FullPresentation);
			OutputNotification.Text = ArrangementParameters.Variants.Presentation;
			OutputNotification.Ref = GetURL(ArrangementParameters.Variants.Array[0]);
		Else
			If ArrangementParameters.Action = "Move" Then
				Pattern = NStr("en='Successfully transferred to %1"".';ru='Успешно перемещены в ""%1"".'");
			Else
				Pattern = NStr("en='Successfully placed in %1"".';ru='Успешно размещены в ""%1"".'");
			EndIf;
			OutputNotification.Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Report variants (%1).';ru='Варианты отчетов (%1).'"),
				Format(ArrangementParameters.Variants.Total, "NZ=0; NG=0"));
			OutputNotification.Title = StringFunctionsClientServer.SubstituteParametersInString(
				Pattern,
				ArrangementParameters.Receiver.FullPresentation);
		EndIf;
	Else
		ErrorsText = "";
		If Not IsBlankString(CannotBeArranged) Then
			ErrorsText = ?(ErrorsText = "", "", ErrorsText + Chars.LF + Chars.LF)
				+ NStr("en='Cannot be placed in command interface:';ru='Не могут размещаться в командном интерфейсе:'")
				+ Chars.LF
				+ CannotBeArranged;
		EndIf;
		If Not IsBlankString(ArrangedAlready) Then
			ErrorsText = ?(ErrorsText = "", "", ErrorsText + Chars.LF + Chars.LF)
				+ NStr("en='Already located in this section:';ru='Уже размещены в этом разделе:'")
				+ Chars.LF
				+ ArrangedAlready;
		EndIf;
		
		If ArrangementParameters.Action = "Move" Then
			Pattern = NStr("en='Transferred report variants: %1 out of %2.';ru='Перемещено вариантов отчетов: %1 из %2.'");
		Else
			Pattern = NStr("en='Placed report variants: %1 of %2.';ru='Размещено вариантов отчетов: %1 из %2.'");
		EndIf;
		
		OutputWarning = ExecutionResult.OutputWarning;
		OutputWarning.Use = True;
		OutputWarning.Text = StringFunctionsClientServer.SubstituteParametersInString(
			Pattern,
			Format(Placed, "NZ=0; NG=0"),
			Format(ArrangementParameters.Variants.Total, "NZ=0; NG=0"));
		OutputWarning.ErrorsText = ErrorsText;
	EndIf;
	
	If ArrangementParameters.Action = "Move" AND Placed > 0 Then
		Items.SubsystemsTree.CurrentRow = ArrangementParameters.Receiver.ID;
		UpdateListContent();
	EndIf;
	
	Return ExecutionResult;
EndFunction

#EndRegion













