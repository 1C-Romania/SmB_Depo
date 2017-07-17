
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ContractsListByDefault = GetContractsByDefault();
	
	If ContractsListByDefault.Count() > 0 Then
		
		SetAppearanceOfContractsByDefault(ContractsListByDefault);
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List.CurrentData);
EndProcedure
// End StandardSubsystems.Printing

&AtServerNoContext
// Function receives and returns the selection of default contracts 
// 
// ArrayCounterparty - array of counterparties for which it is necessary to select the default contracts.
//
Function GetContractsByDefault(ArrayCounterparty = Undefined)
	
	Query			= New Query;
	
	Query.Text	=
	"SELECT ALLOWED
	|	Counterparties.ContractByDefault AS Contract
	|FROM
	|	Catalog.Counterparties AS Counterparties
	|WHERE
	|	(NOT Counterparties.IsFolder)
	|	AND (NOT Counterparties.ContractByDefault = VALUE(Catalog.CounterpartyContracts.EmptyRef))
	|	AND &FilterConditionByCounterparties";
	
	
	Query.Text = StrReplace(Query.Text, 
		"&FilterConditionByCounterparties",
		?(TypeOf(ArrayCounterparty) = Type("Array"), "Counterparties.Ref IN (&ArrayCounterparty)", "True"));
	
	QueryResult			= Query.Execute().Unload();
	
	ContractsListByDefault	= New ValueList;
	ContractsListByDefault.LoadValues(QueryResult.UnloadColumn("Contract"));
	
	Return ContractsListByDefault;
	
EndFunction //GetContractsByDefault()

&AtServer
// Procedure marks the contracts by default in the list
//
Procedure SetAppearanceOfContractsByDefault(ContractsListByDefault)
	
	For Each ConditionalAppearanceItem IN List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" Then
			List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	
	ConditionalAppearanceItemsOfList	= List.SettingsComposer.Settings.ConditionalAppearance.Items;
	ConditionalAppearanceItem			= ConditionalAppearanceItemsOfList.Add();
	
	FilterItem 						= ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue 		= New DataCompositionField("Ref");
	FilterItem.ComparisonType 			= DataCompositionComparisonType.InList;
	FilterItem.RightValue 		= ContractsListByDefault;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,,True,));
	
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = "Preset";
	ConditionalAppearanceItem.Presentation = "Contracts by default";  
	
EndProcedure //SetAppearanceOfContractsByDefault()

&AtClient
// Procedure sets the current record as a default Contract for the owner
//
Procedure SetAsContractByDefault(Command)
	
	ContractsListByDefault = New ValueList;
	
	CurrentListRow = Items.List.CurrentData;
	
	If CurrentListRow = Undefined Then
		
		MessageText = NStr("en='Contract that should be set as the Default contract is not selected';ru='Не выбран договор, который необходимо установить как Договор по умолчанию'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	NewContractByDefault	= CurrentListRow.Ref;
	Counterparty				= CurrentListRow.Owner;
	
	For Each ConditionalAppearanceItem IN List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" AND
			ConditionalAppearanceItem.Presentation = "Contracts by default" Then
			
			FilterItem				= ConditionalAppearanceItem.Filter.Items[0];
			ContractsListByDefault	= FilterItem.RightValue;
			
		EndIf;
	EndDo;
	
	If Not ContractsListByDefault.FindByValue(NewContractByDefault) = Undefined Then
		
		Return;
		
	EndIf;
	
	ChangeCardOfCounterpartyAndChangeListAppearance(Counterparty, NewContractByDefault, ContractsListByDefault);
	
	Notify("RereadContractByDefault");
	
EndProcedure //SetAsContractByDefault()

&AtServer
// Procedure - writes new value in
// counterparty card and updates the visual presentation of the contract by default in the list form
//
Procedure ChangeCardOfCounterpartyAndChangeListAppearance(Counterparty, NewContractByDefault, ContractsListByDefault)
	
	CounterpartyObject 						= Counterparty.GetObject();
	OldContractByDefault				= CounterpartyObject.ContractByDefault;
	CounterpartyObject.ContractByDefault		= NewContractByDefault;
	
	Try
		
		CounterpartyObject.Write();
		
	Except
		
		MessageText = NStr("en='Cannot change the default contract in the counterparty card.';ru='Не удалось поменять договор по умолчанию в карточке контрагента.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndTry;
	
	ValueListItem 					= ContractsListByDefault.FindByValue(OldContractByDefault);
	
	If Not ValueListItem = Undefined Then
		
		ContractsListByDefault.Delete(ValueListItem);
		
	EndIf;
	
	ContractsListByDefault.Add(NewContractByDefault);
	
	SetAppearanceOfContractsByDefault(ContractsListByDefault);
	
EndProcedure //ChangeCardOfCounterpartyAndChangeListAppearance()

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingCounterpartyContracts";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningCounterpartyContracts";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion


