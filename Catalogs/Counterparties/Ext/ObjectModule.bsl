#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var RefTreaty;		 // IN variable new ref for contract creation is stored.
Var ContactPersonRef; // The variable stores the reference for creation of a new contact person.

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

// Procedure checks the TIN and KPP correctness and fixes the counterparty duplicate existence
//
Procedure RegisterCounterpartyDuplicates()
	
	If IsFolder Then
		Return;
	EndIf;
	
	YouNeedToPerformCheck = IsNew();
	
	ThisIsLegalEntity = LegalEntityIndividual = Enums.LegalEntityIndividual.LegalEntity;
	
	TINModified = YouNeedToPerformCheck;
	KPPModified = YouNeedToPerformCheck;
	
	If Not YouNeedToPerformCheck Then
		
		PreviousValueStructure = CommonUse.ObjectAttributesValues(Ref, 
																			  "TIN,
																			  |KPP,
																			  |TINEnteredCorrectly,
																			  |KPPEnteredCorrectly, 
																			  |LegalEntityIndividual");
																			  
		If Not PreviousValueStructure.TIN = TIN 
			Or Not PreviousValueStructure.KPP = KPP 
			Or Not PreviousValueStructure.LegalEntityIndividual = LegalEntityIndividual Then
			
			YouNeedToPerformCheck = True; 
			
		EndIf;
		
		TINModified = Not PreviousValueStructure.TIN = TIN;
		KPPModified = Not PreviousValueStructure.KPP = KPP;
		
		ItWasLegalEntity = PreviousValueStructure.LegalEntityIndividual = Enums.LegalEntityIndividual.LegalEntity;
		
		If YouNeedToPerformCheck 
			AND PreviousValueStructure.TINEnteredCorrectly 
			AND (PreviousValueStructure.KPPEnteredCorrectly Or IsBlankString(PreviousValueStructure.KPP)) Then
			
			If Not PreviousValueStructure.TIN = TIN
				Or Not PreviousValueStructure.KPP = KPP Then
			
				Block = New DataLock;
				
				If Not PreviousValueStructure.TIN = TIN Then
			
					LockItemStillTIN = Block.Add("InformationRegister.CounterpartyDuplicatesExist");
					LockItemStillTIN.SetValue("TIN", PreviousValueStructure.TIN);
					LockItemStillTIN.Mode = DataLockMode.Exclusive;
					
				EndIf;
				
				If Not PreviousValueStructure.KPP = KPP AND ItWasLegalEntity Then
			
					LockItemStillKPP = Block.Add("InformationRegister.CounterpartyDuplicatesExist");
					LockItemStillKPP.SetValue("KPP", PreviousValueStructure.KPP);
					LockItemStillKPP.Mode = DataLockMode.Exclusive;
					
				EndIf;
			
				Block.Lock();
				
			EndIf;
			
			PreviousDuplicateArray = Catalogs.Counterparties.HasRecordsInDuplicatesRegister(TrimAll(PreviousValueStructure.TIN), 
																								  TrimAll(PreviousValueStructure.KPP), 
																								  Ref);
		Else
			PreviousDuplicateArray = New Array;
		EndIf;
		
	Else
		
		PreviousDuplicateArray = New Array;
		
	EndIf;
	
	If YouNeedToPerformCheck Then
		
		TransferParameters = New Structure;
		
		TransferParameters.Insert("TIN",						TIN);
		TransferParameters.Insert("KPP",						KPP);
		TransferParameters.Insert("ThisIsLegalEntity", 				LegalEntityIndividual = PredefinedValue("Enum.LegalEntityIndividual.LegalEntity"));
		TransferParameters.Insert("CheckTIN",				True);
		TransferParameters.Insert("CheckKPP",				True);
		TransferParameters.Insert("ColorHighlightIncorrectValues", StyleColors.ErrorCounterpartyHighlightColor);
		
		ReturnedValue = SmallBusinessClientServer.CheckTINKPPCorrectness(TransferParameters);
		
		FillPropertyValues(ThisObject, ReturnedValue);
		
		If TINEnteredCorrectly AND (KPPEnteredCorrectly Or ReturnedValue.EmptyKPP Or Not ThisIsLegalEntity)
			AND (TINModified Or KPPModified) Then
			
			Block = New DataLock;
			LockItemByTIN = Block.Add("InformationRegister.CounterpartyDuplicatesExist");
			LockItemByTIN.SetValue("TIN", TIN);
			LockItemByTIN.Mode = DataLockMode.Exclusive;
			
			If LegalEntityIndividual = Enums.LegalEntityIndividual.LegalEntity Then
				
				LockItemByKPP = Block.Add("InformationRegister.CounterpartyDuplicatesExist");
				LockItemByKPP.SetValue("KPP", KPP);
				LockItemByTIN.Mode = DataLockMode.Exclusive;
				
			EndIf;
			
			Block.Lock();
			
			DuplicateArray = Catalogs.Counterparties.CheckCatalogDuplicatesCounterpartiesByTINKPP(TrimAll(TIN), 
																								TrimAll(KPP), 
																								Ref, True);
																								
			If DuplicateArray.Count() > 0 Then
				
				// For new item reference will be available only OnWrite, there also we will write.
				AdditionalProperties.YouNeedToWriteInRegisterOnWrite = True;
				
				For Each ArrayElement IN DuplicateArray Do
					Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(ArrayElement, TIN, KPP, False);
				EndDo;
				
			EndIf;
			
			If PreviousDuplicateArray.Count() > 0 Then
				
				Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(Ref, PreviousValueStructure.TIN, PreviousValueStructure.KPP, True);
				
				If PreviousDuplicateArray.Count() = 1 Then
					Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(PreviousDuplicateArray[0], PreviousValueStructure.TIN, PreviousValueStructure.KPP, True);
				EndIf;
				
			EndIf;
			
		Else
			
			If PreviousDuplicateArray.Count() > 0 Then
				
				Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(Ref, PreviousValueStructure.TIN, PreviousValueStructure.KPP, True);
			
				If PreviousDuplicateArray.Count() = 1 Then
					Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(PreviousDuplicateArray[0], PreviousValueStructure.TIN, PreviousValueStructure.KPP, True);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure clears the register CounterpartyDuplicateExist
//
Procedure DeleteDuplicateRegistrationBeforeDelete()
	
	DuplicateArray = Catalogs.Counterparties.HasRecordsInDuplicatesRegister(TrimAll(TIN), TrimAll(KPP), Ref);
	
	If DuplicateArray.Count() = 1 Then
		
		ThisIsLegalEntity = LegalEntityIndividual = Enums.LegalEntityIndividual.LegalEntity;
		
		Block = New DataLock;
		LockItemStillTIN = Block.Add("InformationRegister.CounterpartyDuplicatesExist");
		LockItemStillTIN.SetValue("TIN", TIN);
		LockItemStillTIN.Mode = DataLockMode.Exclusive;
		
		If ThisIsLegalEntity Then
			
			LockItemStillKPP = Block.Add("InformationRegister.CounterpartyDuplicatesExist");
			LockItemStillKPP.SetValue("KPP", KPP);
			LockItemStillKPP.Mode = DataLockMode.Exclusive;
			
		EndIf;
		
		Block.Lock();
		
		Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(DuplicateArray[0], TIN, KPP, True);
		
	EndIf;
	
EndProcedure

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

#Region EventsHandlers

// Procedure - FillCheckProcessing event handler.
//
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
	
	If Not IsFolder AND IsNew() Then
		CreationDate = CurrentDate();
	EndIf;
	
	AdditionalProperties.Insert("YouNeedToWriteInRegisterOnWrite", False);
	
	If DataExchange.Load Then
		
		If Not (AdditionalProperties.Property("RegisterCounterpartiesDuplicates")
			AND AdditionalProperties.RegisterCounterpartiesDuplicates = False) Then
				RegisterCounterpartyDuplicates();
		EndIf;
		
		Return;
		
	Else
		RegisterCounterpartyDuplicates();
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
		KPP = "";
		CodeByOKPO = "";
		BankAccountByDefault = Undefined;
		ContractByDefault = Undefined;
	EndIf;
	
EndProcedure

// event handler BeforeDelete
//
Procedure BeforeDelete(Cancel)
	
	DeleteDuplicateRegistrationBeforeDelete();
	
EndProcedure

#EndRegion

#EndIf