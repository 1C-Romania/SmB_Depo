#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var RefTreaty;		 // IN variable new ref for contract creation is stored.
Var ContactPersonRef; // The variable stores the reference for creation of a new contact person.

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	NoncheckableAttributeArray = New Array;
	
	If Not Catalogs.CounterpartiesAccessGroups.AccessGroupsAreUsed() Then
		NoncheckableAttributeArray.Add("AccessGroup");
	EndIf;
	
	CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, NoncheckableAttributeArray);
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel)
	
	AdditionalProperties.Insert("YouNeedToWriteInRegisterOnWrite", False);
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder AND IsNew() Then
		CreationDate = CurrentDate();
	EndIf;
	
	RefTreaty = Undefined;
	
	// It is required to fill main contract
	If Not IsFolder AND Not ValueIsFilled(ContractByDefault) Then
		
		If IsNew() Then
			
			// Create a ref to the contract which will
			// be created after counterparty write and write it in attribute ContractByDefault
			RefTreaty = Catalogs.CounterpartyContracts.GetRef();
			ContractByDefault = RefTreaty;
			
		Else
			
			// Try to find already created contract
			Query = New Query(
			"SELECT
			|	CounterpartyContracts.Ref AS Contract
			|FROM
			|	Catalog.CounterpartyContracts AS CounterpartyContracts
			|WHERE
			|	CounterpartyContracts.Owner = &Owner");
			
			Query.SetParameter("Owner", Ref);
			Selection = Query.Execute().Select();
			
			If Selection.Next() Then
				// If found, then we take the first one found
				ContractByDefault = Selection.Contract;
			Else
				// If didn't find - create new
				ContractByDefault = CreateDefaultContract();
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Not IsFolder
		AND AdditionalProperties.Property("ContactPersonData")
		AND TypeOf(AdditionalProperties.ContactPersonData) = Type("Structure") Then
		
		ContactPersonRef = Catalogs.ContactPersons.GetRef();
		ContactPerson = ContactPersonRef;
		
	EndIf;
	
EndProcedure // BeforeWrite()

// Procedure - event handler OnWrite.
//
Procedure OnWrite(Cancel)
	
	If AdditionalProperties.YouNeedToWriteInRegisterOnWrite Then
		Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(Ref, TIN, KPP, False);
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Create the counterparty contract by reference created in event BeforeWrite
	If RefTreaty <> Undefined Then
		CreateDefaultContract();
	EndIf;
	
	// Create a contact person by reference created in event BeforeWrite
	If ContactPersonRef <> Undefined Then
		CreateContactPersonByStRegistriesData();
	EndIf;
	
EndProcedure // OnRecord()

// Event handler OnCopy
//
Procedure OnCopy(CopiedObject)
	
	If Not IsFolder Then
		TIN = "";
		BankAccountByDefault = Undefined;
		ContractByDefault = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// The function creates a new default contract.
//
Function CreateDefaultContract()
	
	SetPrivilegedMode(True);
	
	NewContract = Catalogs.CounterpartyContracts.CreateItem();
	
	If RefTreaty <> Undefined Then
		NewContract.SetNewObjectRef(RefTreaty);
	EndIf;
	
	CompanyByDefault = SmallBusinessReUse.GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainCompany");
	If Not ValueIsFilled(CompanyByDefault) Then
		CompanyByDefault = Catalogs.Companies.MainCompany;
	EndIf;
	
	NewContract.Description		= "Main contract";
	NewContract.SettlementsCurrency		= Constants.NationalCurrency.Get();
	NewContract.Company		= CompanyByDefault;
	NewContract.ContractKind		= Enums.ContractKinds.WithCustomer;
	NewContract.PriceKind				= Catalogs.PriceKinds.GetMainKindOfSalePrices();
	NewContract.Owner			= Ref;
	NewContract.VendorPaymentDueDate = Constants.VendorPaymentDueDate.Get();
	NewContract.CustomerPaymentDueDate = Constants.CustomerPaymentDueDate.Get();
	
	// Let's fill in the type of counterparty's prices
	NewCounterpartyPriceKind = Catalogs.CounterpartyPriceKind.CounterpartyDefaultPriceKind(Ref);
	
	If Not ValueIsFilled(NewCounterpartyPriceKind) Then 
		
		NewCounterpartyPriceKind = Catalogs.CounterpartyPriceKind.FindAnyFirstKindOfCounterpartyPrice(Ref);
		
		If Not ValueIsFilled(NewCounterpartyPriceKind) Then
			
			NewCounterpartyPriceKind = Catalogs.CounterpartyPriceKind.CreateCounterpartyPriceKind(Ref, NewContract.SettlementsCurrency);
			
		EndIf;
		
	EndIf;
	
	NewContract.CounterpartyPriceKind = NewCounterpartyPriceKind;
	
	NewContract.Write();
	
	SetPrivilegedMode(False);
	
	Return NewContract.Ref;
	
EndFunction // CreateDefaultContract()

// See description in the comments to the same name procedure in module AccessManagement.
//
Procedure FillAccessValueSets(Table) Export
	
	// Restriction logic:
	// Read, Change: object is allowed by access type CounterpartyAccessGroups.
	
	String = Table.Add();
	String.AccessValue = Ref;
	
EndProcedure

// Function creates a contact person by data of common government registries.
//
Function CreateContactPersonByStRegistriesData()
	
	DataCL = AdditionalProperties.ContactPersonData;
	
	NewContactPerson = Catalogs.ContactPersons.CreateItem();
	If ContactPersonRef <> Undefined Then
		NewContactPerson.SetNewObjectRef(ContactPersonRef);
	EndIf;
	
	FillPropertyValues(NewContactPerson, DataCL);
	NewContactPerson.Owner = Ref;
	NewContactPerson.ConnectionRegistrationDate = CurrentDate();
	NewContactPerson.Responsible = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
	NewContactPerson.Description = DataCL.Surname
	+ ?(ValueIsFilled(DataCL.Name), " " + DataCL.Name, "")
	+ ?(ValueIsFilled(DataCL.Patronymic), " " + DataCL.Patronymic, "");
	
	NewContactPerson.Write();
	
	Return NewContactPerson.Ref;
	
EndFunction

#EndRegion

#EndIf