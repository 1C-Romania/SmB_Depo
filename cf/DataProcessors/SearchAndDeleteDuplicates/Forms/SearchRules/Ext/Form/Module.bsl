// Parameters are awaited:
//
//     DuplicateSearchArea        - String               - Metadata full name of previously selected search area table.
//     SelectionAreaPresentation - String               - Presentation for title forming.
//     AppliedRulesDescription   - String, Undefined - Text of the applied rules. If not specified, then
//                                  there are no applied rules.
//
//     SettingsAddress - String - Address of a settings temporary storage. Structure with margins is awaited:
//         ConsiderAppliedRules - Boolean - The previous setting check box, by default, True
//         SearchRules              - ValueTable - Edited settings. Columns are awaited:
//             Attribute - String  - Attribute name for comparison.
//             AttributePresentation - String - Presentation of attribute for comparison
//             Rule - String  - Selected comparison variant: Equals - match by quality, Details -
//                                 match by similarity, - do not take into account.
//             ComparisonVariants - ValueList - Available comparison variants, where value - one of
//                                                  the rules variants.
//
// Returned as a selection result:
//     Undefined - Reject editing.
//     String       - Address of a temporary storage of new settings, refers
//                    to the structure similar to the SettingsAddress parameter.
//

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("AppliedRulesDescription", AppliedRulesDescription);
	DuplicateSearchArea = Parameters.DuplicateSearchArea;

	Title = StrReplace( NStr("en='Duplicates search rules %1';ru='Правила поиска дублей ""%1""'"), "%1", Parameters.SelectionAreaPresentation);
	
	InitialSettings = GetFromTempStorage(Parameters.SettingsAddress);
	DeleteFromTempStorage(Parameters.SettingsAddress);
	InitialSettings.Property("ConsiderAppliedRules", ConsiderAppliedRules);
	
	If AppliedRulesDescription = Undefined Then
		// Rules are not defined
		Items.AppliedRestrictionsGroup.Visible = False;
	Else
		Items.ConsiderAppliedRules.Visible = CanCancelAppliedRules();
	EndIf;
	
	// Import and correct rules.
	SearchRules.Load(InitialSettings.SearchRules);
	For Each RuleRow IN SearchRules Do
		RuleRow.Use = Not IsBlankString(RuleRow.Rule);
	EndDo;
	
	For Each Item IN InitialSettings.AllComparisonVariants Do
		If Not IsBlankString(Item.Value) Then
			FillPropertyValues(AllCompareKindsSearchRules.Add(), Item);
		EndIf;
	EndDo;
	
	SetColorAndConditionalDesign();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ThisObject.RefreshDataRepresentation();
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtClient
Procedure ConsiderAppliedRulesOnChange(Item)
	
	If ConsiderAppliedRules Then
		Return;
	EndIf;
	
	Description = New NotifyDescription("EndAppliedRulesUseCleaning", ThisObject);
	
	HeaderText = NStr("en='Warning';ru='Предупреждение'");
	QuestionText   = NStr("en='Warning: searching and deleting item duplicates ignoring delivered restrictions may lead to data misalignment in the application.
		|
		|Disable delivered restrictions use?';ru='Внимание: поиск и удаление дублей элементов без учета поставляемых ограничений может привести к рассогласованию данных в программе.
		|
		|Отключить использование поставляемых ограничений?'");
	
	ShowQueryBox(Description, QuestionText, QuestionDialogMode.YesNo,,DialogReturnCode.No, HeaderText);
EndProcedure

#EndRegion

#Region SearchRulesTablesEventsHandlers

&AtClient
Procedure SearchRulesUseOnChange(Item)
	
	CurrentData = Items.SearchRules.CurrentData;
	
	If CurrentData.Use Then
		If IsBlankString(CurrentData.Rule) AND CurrentData.ComparisonVariants.Count() > 0 Then
			CurrentData.Rule = CurrentData.ComparisonVariants[0].Value
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SearchRulesComparisonTypeSelectionStart(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	CurrentData = Items.SearchRules.CurrentData;
	ChoiceData = CurrentData.ComparisonVariants;
	
EndProcedure

&AtClient
Procedure SearchRulesComparisonTypeSelectionStartFromList(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure SearchRulesComparisonTypeSelectionDataProcessor(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	
	CurrentData = Items.SearchRules.CurrentData;
	CurrentData.Use = True;
	CurrentData.Rule      = ValueSelected;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	SelectionErrorsText = SelectionErrors();
	If SelectionErrorsText <> Undefined Then
		ShowMessageBox(, SelectionErrorsText);
		Return;
	EndIf;
	
	If Modified Then
		NotifyChoice( ChoiceResult() );
	Else
		Close();
	EndIf;
		
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Function SelectionErrors() 
	
	If AppliedRulesDescription <> Undefined AND ConsiderAppliedRules Then
		// There are applied rules and they are used - no errors.
		Return Undefined;
	EndIf;
	
	For Each RulesRow IN SearchRules Do
		If RulesRow.Use Then
			// Custom rule is specified - no errors.
			Return Undefined;
		EndIf;
	EndDo;
	
	Return NStr("en='You need to specify at least one rule of duplicates search.';ru='Необходимо указать хотя бы одно правило поиска дублей.'");
EndFunction

&AtClient
Procedure EndAppliedRulesUseCleaning(Val Response, Val AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		Return 
	EndIf;
	
	ConsiderAppliedRules = True;
EndProcedure

&AtServerNoContext
Function CanCancelAppliedRules()
	
	Result = AccessRight("DataAdministration", Metadata);
	Return Result;
	
EndFunction

&AtServer
Function ChoiceResult()
	
	Result = New Structure;
	Result.Insert("ConsiderAppliedRules", ConsiderAppliedRules);
	
	SelectedRules = SearchRules.Unload();
	For Each RulesRow IN SelectedRules  Do
		If Not RulesRow.Use Then
			RulesRow.Rule = "";
		EndIf;
	EndDo;
	SelectedRules.Columns.Delete("Use");
	
	Result.Insert("SearchRules", SelectedRules );
	
	Return PutToTempStorage(Result);
EndFunction

&AtServer
Procedure SetColorAndConditionalDesign()
	ConditionalDesignItems = ConditionalAppearance.Items;
	ConditionalDesignItems.Clear();
	
	ColorInaccessibleData = StyleColorOrAuto("ColorInaccessibleData", 192, 192, 192);
	
	For Each ItemOfList IN AllCompareKindsSearchRules Do
		DesignElement = ConditionalDesignItems.Add();
		
		AppearanceFilter = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
		AppearanceFilter.LeftValue = New DataCompositionField("SearchRules.Rule");
		AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
		AppearanceFilter.RightValue = ItemOfList.Value;
		
		AppearanceField = DesignElement.Fields.Items.Add();
		AppearanceField.Field = New DataCompositionField("SearchRulesComparisonType");
		
		DesignElement.Appearance.SetParameterValue("Text", ItemOfList.Presentation);
	EndDo;
	
	// Don't use
	DesignElement = ConditionalDesignItems.Add();
	
	AppearanceFilter = DesignElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("SearchRules.Use");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = False;
	
	AppearanceField = DesignElement.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("SearchRulesComparisonType");
	
	DesignElement.Appearance.SetParameterValue("TextColor", ColorInaccessibleData);
EndProcedure

&AtServerNoContext
Function StyleColorOrAuto(Val Name, Val Red = Undefined, Green = Undefined, Blue = Undefined)

	StyleItem = Metadata.StyleItems.Find(Name);
	If StyleItem <> Undefined AND StyleItem.Type = Metadata.ObjectProperties.StyleElementType.Color Then
		Return StyleColors[Name];
	EndIf;
	
	Return ?(Red = Undefined, New Color, New Color(Red, Green, Blue));
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
