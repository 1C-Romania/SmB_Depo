
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Sets the filter and conditional list appearance if a counterparty has the flag of settlements under the contracts.
//
&AtServer
Procedure SetFilterAndConditionalAppearance()
	
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem IN List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset"
			AND ConditionalAppearanceItem.Presentation = "Mismatch to documents conditions" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item IN ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	If Not ControlContractChoice Then
		Return;
	EndIf;
	
	SmallBusinessClientServer.SetListFilterItem(List,"Owner",Parameters.Counterparty);
	
	If Not ControlCorrespondenceWithDocument Then
		Return;
	EndIf;
	
	ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	
	OrGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	OrGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	OrGroup.Use = True;
	
	FilterItem = OrGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Company");
	FilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	FilterItem.RightValue = Company;
	
	FilterItem = OrGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("ContractKind");
	FilterItem.ComparisonType = DataCompositionComparisonType.NotInList;
	FilterItem.RightValue = ContractKinds;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.DarkGray);
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = "Preset";
	ConditionalAppearanceItem.Presentation = "Mismatch to documents conditions";
	
EndProcedure

// Checks the matching of the contract attributes "Company" and "ContractKind" to the passed parameters.
//
&AtServerNoContext
Function CheckContractToDocumentConditionAccordance(ControlCorrespondenceWithDocument, MessageText, Contract, Company, Counterparty, ContractKindsList)
	
	If Not ControlCorrespondenceWithDocument Then
		Return True;
	EndIf;
	
	Return Catalogs.CounterpartyContracts.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("ControlContractChoice", ControlContractChoice);
	Parameters.Property("Company"  , Company);
	Parameters.Property("Counterparty"   , Counterparty);
	Parameters.Property("ContractKinds", ContractKinds);
	
	If Not SmallBusinessReUse.CounterpartyContractsControlNeeded() Then
		ControlCorrespondenceWithDocument = False;
	Else
		ControlCorrespondenceWithDocument = ControlContractChoice;
	EndIf;
	
	SetFilterAndConditionalAppearance();
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, ThisForm.CommandBar);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - event handler ValueSelection of the List table.
//
&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	QuestionText = "";
	If Not CheckContractToDocumentConditionAccordance(ControlCorrespondenceWithDocument, QuestionText, Value, Company, Counterparty, ContractKinds) Then
		
		StandardProcessing = False;
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("Value", Value);
		
		NotifyDescription = New NotifyDescription("ValueChoiceListEnd", ThisObject, QuestionParameters);
		QuestionText = QuestionText + NStr("en='
		|
		|Select other contract?';ru='
		|
		|Выбрать другой договор?'");
		
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ValueChoiceListEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		NotifyChoice(AdditionalParameters.Value);
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeAddingBegin of the List table.
//
&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If ControlContractChoice
		AND ValueIsFilled(Counterparty)
		AND ValueIsFilled(Company)
		AND ContractKinds.Count() > 0 Then
		
		Cancel = True;
		
		FillingDataContract = New Structure;
		FillingDataContract.Insert("Owner", Counterparty);
		FillingDataContract.Insert("Company", Company);
		FillingDataContract.Insert("ContractKind", ContractKinds[0].Value);
		
		FormParameters = New Structure;
		FormParameters.Insert("FillingValues", FillingDataContract);
		
		OpenForm("Catalog.CounterpartyContracts.ObjectForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List.CurrentData);
EndProcedure
// End StandardSubsystems.Printing