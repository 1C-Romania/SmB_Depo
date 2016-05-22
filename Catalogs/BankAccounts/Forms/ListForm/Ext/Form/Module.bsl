
#Region ServiceProceduresAndFunctions

&AtServerNoContext
// Function receives and returns a selection of banks. accounts by default 
// 
// ArrayCounterparty - array of counterparties for which it is necessary to select the default contracts.
//
Function GetBankOfAccountByDefault(ArrayOfOwners = Undefined)
	
	Query			= New Query;
	
	Query.Text	=
	"SELECT ALLOWED
	|	Counterparties.BankAccountByDefault AS BankAccount
	|FROM
	|	Catalog.Counterparties AS Counterparties
	|WHERE
	|	Not Counterparties.IsFolder
	|	AND Not Counterparties.BankAccountByDefault = VALUE(Catalog.BankAccounts.EmptyRef)
	|	AND &FilterConditionByCounterparties
	|
	|UNION ALL
	|
	|SELECT
	|	Companies.BankAccountByDefault
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Not Companies.BankAccountByDefault = VALUE(Catalog.BankAccounts.EmptyRef)
	|	AND &FilterConditionByCompanies";
	
	Query.Text = StrReplace(Query.Text, 
		"&FilterConditionByCounterparties",
		?(TypeOf(ArrayOfOwners) = Type("Array"), "Counterparty.Ref IN (&ArrayOfOwners)", "True"));
		
	Query.Text = StrReplace(Query.Text, 
		"&FilterConditionByCompanies",
		?(TypeOf(ArrayOfOwners) = Type("Array"), "Companies.Ref IN (&ArrayOfOwners)", "True"));
		
	QueryResult			= Query.Execute().Unload();
	
	ListOfBankAccountsByDefault	= New ValueList;
	ListOfBankAccountsByDefault.LoadValues(QueryResult.UnloadColumn("BankAccount"));
	
	Return ListOfBankAccountsByDefault;
	
EndFunction //GetContractsByDefault()

&AtServer
// Procedure selects a bank in the list. accounts by default
//
Procedure SetAppearanceOfBankAccountsByDefault(ListOfBankAccountsByDefault)
	
	For Each ConditionalAppearanceItem IN List.SettingsComposer.FixedSettings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" Then
			List.SettingsComposer.FixedSettings.ConditionalAppearance.Items.Delete(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	
	ConditionalAppearanceItemsOfList	= List.SettingsComposer.FixedSettings.ConditionalAppearance.Items;
	ConditionalAppearanceItem			= ConditionalAppearanceItemsOfList.Add();
	
	FilterItem 						= ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue 		= New DataCompositionField("Ref");
	FilterItem.ComparisonType 			= DataCompositionComparisonType.InList;
	FilterItem.RightValue 		= ListOfBankAccountsByDefault;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,,True,));
	
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = "Preset";
	ConditionalAppearanceItem.Presentation = "Contracts by default";  
	
EndProcedure //SetAppearanceOfContractsByDefault()

&AtServer
// Procedure - writes a new value
// to the owner card and updates the visual presentation bank. accounts by default in the list form
//
Procedure ChangeCardOfObjectOwnerAndChangeListAppearance(OwnerRef, NewBankAccountAsDefault, ListOfBankAccountsByDefault)
	
	OwnerObject 							= OwnerRef.GetObject();
	OldBankAccountByDefault				= OwnerObject.BankAccountByDefault;
	OwnerObject.BankAccountByDefault= NewBankAccountAsDefault;
	
	Try
		
		OwnerObject.Write();
		
	Except
		
		MessageText = NStr("en = 'Failed to change bank account in owner card by default.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndTry;
	
	ValueListItem 					= ListOfBankAccountsByDefault.FindByValue(OldBankAccountByDefault);
	
	If Not ValueListItem = Undefined Then
		
		ListOfBankAccountsByDefault.Delete(ValueListItem);
		
	EndIf;
	
	ListOfBankAccountsByDefault.Add(NewBankAccountAsDefault);
	
	SetAppearanceOfBankAccountsByDefault(ListOfBankAccountsByDefault);
	
EndProcedure //ChangeCardHolderAndChangeAppearanceList()

#EndRegion

#Region FormEvents

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	ListOfBankAccountsByDefault = GetBankOfAccountByDefault();
	If ListOfBankAccountsByDefault.Count() > 0 Then
		
		SetAppearanceOfBankAccountsByDefault(ListOfBankAccountsByDefault);
		
	EndIf;
	
	Items.AgreementOnDirectExchange.Visible = GetFunctionalOption("UseEDExchangeWithBanks");
	If Parameters.Filter.Property("Owner") Then
		OwnerType = TypeOf(Parameters.Filter.Owner);
		Items.AgreementOnDirectExchange.Visible =
			GetFunctionalOption("UseEDExchangeWithBanks") AND OwnerType = Type("CatalogRef.Companies");
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure // OnCreateAtServer()

#EndRegion

#Region CommandHandlers

&AtClient
// Sets the current item as the default bank account for the owner
//
Procedure SetAsBankAccountByDefault(Command)
	
	ListOfBankAccountsByDefault = New ValueList;
	
	CurrentListRow = Items.List.CurrentData;
	
	If CurrentListRow = Undefined Then
		
		MessageText = NStr("en = 'Bank account to be set as a default is not selected.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	NewBankAccountAsDefault	= CurrentListRow.Ref;
	OwnerRef				= CurrentListRow.Owner;
	
	For Each ConditionalAppearanceItem IN List.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" AND
			ConditionalAppearanceItem.Presentation = "Default bank account" Then
			
			FilterItem				= ConditionalAppearanceItem.Filter.Items[0];
			ListOfBankAccountsByDefault	= FilterItem.RightValue;
			
		EndIf;
	EndDo;
	
	If Not ListOfBankAccountsByDefault.FindByValue(NewBankAccountAsDefault) = Undefined Then
		
		Return;
		
	EndIf;
	
	ChangeCardOfObjectOwnerAndChangeListAppearance(OwnerRef, NewBankAccountAsDefault, ListOfBankAccountsByDefault);
	
	Notify("DefaultBankAccountChanged");
	
EndProcedure // SetAsBankAccountByDefault()

#EndRegion


#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingBankAccounts";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningBankAccounts";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion
