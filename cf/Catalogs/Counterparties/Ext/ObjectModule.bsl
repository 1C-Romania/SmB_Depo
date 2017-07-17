#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("Structure") And Not IsFolder Then
		
		FillPropertyValues(ThisObject, FillingData);
		
	EndIf;
	
	FillByDefault();
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	NoncheckableAttributeArray = New Array;
	
	If Not Catalogs.CounterpartiesAccessGroups.AccessGroupsAreUsed() Then
		NoncheckableAttributeArray.Add("AccessGroup");
	EndIf;
	
	CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, NoncheckableAttributeArray);
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	// 1. Actions which are always executed, including the exchange of data
	
	AdditionalProperties.Insert("NeedToWriteInRegisterOnWrite", False);
	
	// No execute action in the data exchange
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsNew() Then
		CheckChangePossibility(Cancel);
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If Not (AdditionalProperties.Property("RegisterCounterpartyDuplicates") And AdditionalProperties.RegisterCounterpartyDuplicates = False) Then
		RegisterCounterpartyDuplicates();
	EndIf;
		
	If Not IsFolder AND IsNew() Then
		CreationDate = CurrentDate();
	EndIf;
	If Not IsFolder Then
		GenerateBasicInformation();
	EndIf;
	

	RefTreaty = Undefined;
	
	// Fill default contract: substitute any existing or create a new
	If Not IsFolder AND Not ValueIsFilled(ContractByDefault) Then
		
		NeedCreateContract	= True;
		
		If Not IsNew() Then
			
			Query = New Query;
			Query.Text = 
				"SELECT TOP 1
				|	CounterpartyContracts.Ref AS Contract
				|FROM
				|	Catalog.CounterpartyContracts AS CounterpartyContracts
				|WHERE
				|	CounterpartyContracts.Owner = &Owner
				|	AND CounterpartyContracts.DeletionMark = FALSE
				|
				|ORDER BY
				|	CounterpartyContracts.ContractNo DESC";
			
			Query.SetParameter("Owner", Ref);
			
			QueryResult = Query.Execute();
			
			If Not QueryResult.IsEmpty() Then
				
				Selection = QueryResult.Select();
				Selection.Next();
				ContractByDefault = Selection.Contract;
				
				NeedCreateContract = False;
				
			EndIf;
			
		EndIf;
		
		If NeedCreateContract Then
			ContractByDefault = Catalogs.CounterpartyContracts.GetRef();
			AdditionalProperties.Insert("NewMainContract", ContractByDefault);
		EndIf;
		
	EndIf;
	
	BringDataToConsistentState();
	
EndProcedure // BeforeWrite()

Procedure OnWrite(Cancel)
	
	If AdditionalProperties.NeedToWriteInRegisterOnWrite Then
		Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(Ref, TIN, False);
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Create a counterparty contract by reference created in the event BeforeWrite()
	If Not IsFolder And AdditionalProperties.Property("NewMainContract") Then
		
		ContractObject = Catalogs.CounterpartyContracts.CreateItem();
		ContractObject.Fill(Ref);
		
		ContractObject.SetNewObjectRef(AdditionalProperties.NewMainContract);
		ContractObject.Write();
		
		AdditionalProperties.Delete("NewMainContract");
		
	EndIf;
	
EndProcedure // OnWrite()

Procedure OnCopy(CopiedObject)
	
	If Not IsFolder Then
		BankAccountByDefault	= Undefined;
		ContractByDefault		= Undefined;
		ContactPerson			= Undefined;
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DeleteDuplicateRegistrationBeforeDelete();
	
EndProcedure

#EndRegion

#Region Interface

// Procedure fills an auxiliary attribute "BasicInformation"
//
Procedure GenerateBasicInformation() Export
	
	RowsArray = New Array;
	
	If Not IsBlankString(DescriptionFull) Then
		RowsArray.Add(DescriptionFull);
	EndIf;
	
	If Not IsBlankString(TIN) Then
		RowsArray.Add(NStr("ru='ИНН'; en = 'TIN'") + " " + TIN);
	EndIf;
	
	CI = ContactInformation.Unload();
	CI.Sort("Kind");
	For Each RowCI In CI Do
		If IsBlankString(RowCI.Presentation) Then
			Continue;
		EndIf;
		RowsArray.Add(RowCI.Presentation);
	EndDo;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ContactPersons.Description AS Description,
	|	ContactPersons.ContactInformation.(
	|		Presentation AS Presentation,
	|		Kind AS KindCI
	|	)
	|FROM
	|	Catalog.ContactPersons AS ContactPersons
	|WHERE
	|	ContactPersons.Owner = &Counterparty
	|	AND ContactPersons.DeletionMark = FALSE
	|
	|ORDER BY
	|	Description,
	|	KindCI";
	
	Query.SetParameter("Counterparty", Ref);
	
	SelectionCP = Query.Execute().Select();
	While SelectionCP.Next() Do
		
		If RowsArray.Count() > 0 Then
			RowsArray.Add(Chars.LF);
		EndIf;
		RowsArray.Add(SelectionCP.Description);
		
		SelectionCI = SelectionCP.ContactInformation.Select();
		While SelectionCI.Next() Do
			If IsBlankString(SelectionCI.Presentation) Then
				Continue;
			EndIf;
			RowsArray.Add(SelectionCI.Presentation);
		EndDo;
		
	EndDo;
	
	If Not IsBlankString(Comment) Then
		RowsArray.Add(Comment);
	EndIf;
	
	If ValueIsFilled(Responsible) Then
		RowsArray.Add(CommonUse.ObjectAttributeValue(Responsible, "Description"));
	EndIf;
	
	BasicInformation = StrConcat(RowsArray, Chars.LF);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure FillByDefault()
	
	If IsFolder Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Responsible) Then
		Responsible = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
	EndIf;
	
EndProcedure

// Procedure checks the TIN correctness and fixes the counterparty duplicate existence
//
Procedure RegisterCounterpartyDuplicates()
	
	If IsFolder Then
		Return;
	EndIf;
	
	NeedToCheck = IsNew();
	
	IsLegalEntity = LegalEntityIndividual = Enums.CounterpartyKinds.LegalEntity;
	
	TINModified = NeedToCheck;
	
	If Not NeedToCheck Then
		
		PreviousValueStructure = CommonUse.ObjectAttributesValues(Ref, 
																  "TIN,
																  |LegalEntityIndividual");
																			  
		If Not PreviousValueStructure.TIN = TIN 
			Or Not PreviousValueStructure.LegalEntityIndividual = LegalEntityIndividual Then
			
			NeedToCheck = True; 
			
		EndIf;
		
		TINModified = Not PreviousValueStructure.TIN = TIN;
		
		WasLegalEntity = PreviousValueStructure.LegalEntityIndividual = Enums.CounterpartyKinds.LegalEntity;
		
		If NeedToCheck Then
			
			If Not PreviousValueStructure.TIN = TIN Then
			
				Block = New DataLock;
				
				If Not PreviousValueStructure.TIN = TIN Then
			
					LockItemStillTIN = Block.Add("InformationRegister.CounterpartyDuplicatesExist");
					LockItemStillTIN.SetValue("TIN", PreviousValueStructure.TIN);
					LockItemStillTIN.Mode = DataLockMode.Exclusive;
					
				EndIf;
				
				Block.Lock();
				
			EndIf;
			
			PreviousDuplicateArray = Catalogs.Counterparties.HasRecordsInDuplicatesRegister(TrimAll(PreviousValueStructure.TIN), Ref);
		Else
			PreviousDuplicateArray = New Array;
		EndIf;
		
	Else
		
		PreviousDuplicateArray = New Array;
		
	EndIf;
	
	If NeedToCheck Then
		
		If TINModified Then
			
			Block = New DataLock;
			LockItemByTIN = Block.Add("InformationRegister.CounterpartyDuplicatesExist");
			LockItemByTIN.SetValue("TIN", TIN);
			LockItemByTIN.Mode = DataLockMode.Exclusive;
			
			Block.Lock();
			
			DuplicateArray = Catalogs.Counterparties.CheckCatalogDuplicatesCounterpartiesByTIN(TrimAll(TIN), Ref, True);
																								
			If DuplicateArray.Count() > 0 Then
				
				// For new item reference will be available only OnWrite, there also we will write.
				AdditionalProperties.NeedToWriteInRegisterOnWrite = True;
				
				For Each ArrayElement IN DuplicateArray Do
					Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(ArrayElement, TIN, False);
				EndDo;
				
			EndIf;
			
			If PreviousDuplicateArray.Count() > 0 Then
				
				Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(Ref, PreviousValueStructure.TIN, True);
				
				If PreviousDuplicateArray.Count() = 1 Then
					Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(PreviousDuplicateArray[0], PreviousValueStructure.TIN, True);
				EndIf;
				
			EndIf;
			
		Else
			
			If PreviousDuplicateArray.Count() > 0 Then
				
				Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(Ref, PreviousValueStructure.TIN, True);
			
				If PreviousDuplicateArray.Count() = 1 Then
					Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(PreviousDuplicateArray[0], PreviousValueStructure.TIN, True);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure clears the register CounterpartyDuplicateExist
//
Procedure DeleteDuplicateRegistrationBeforeDelete()
	
	DuplicateArray = Catalogs.Counterparties.HasRecordsInDuplicatesRegister(TrimAll(TIN), Ref);
	
	If DuplicateArray.Count() = 1 Then
		
		Block = New DataLock;
		LockItemStillTIN = Block.Add("InformationRegister.CounterpartyDuplicatesExist");
		LockItemStillTIN.SetValue("TIN", TIN);
		LockItemStillTIN.Mode = DataLockMode.Exclusive;
		
		Block.Lock();
		
		Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(DuplicateArray[0], TIN, True);
		
	EndIf;
	
EndProcedure

// The procedure checks the consistency of the data in IB
//
// Parameters:
//  Cancel	 - 	Boolean - Establish True in the case of inconsistent data
//
Procedure CheckChangePossibility(Cancel)
	
	// Barring changes in analysts account for mutual counterparty if movements on registers settlements.
	
	PreviousValues = CommonUse.ObjectAttributesValues(Ref,
		"DoOperationsByContracts,DoOperationsByDocuments,DoOperationsByOrders");
		
	If DoOperationsByContracts <> PreviousValues.DoOperationsByContracts
		Or DoOperationsByDocuments <> PreviousValues.DoOperationsByDocuments
		Or DoOperationsByOrders <> PreviousValues.DoOperationsByOrders Then
		
		Query = New Query;
		Query.Text = 
		"SELECT TOP 1
		|	AccountsReceivable.Counterparty
		|FROM
		|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
		|WHERE
		|	AccountsReceivable.Counterparty = &Counterparty
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	AccountsPayable.Counterparty
		|FROM
		|	AccumulationRegister.AccountsPayable AS AccountsPayable
		|WHERE
		|	AccountsPayable.Counterparty = &Counterparty";
		
		Query.SetParameter("Counterparty", Ref);
		
		SetPrivilegedMode(True);
		QueryResult = Query.Execute();
		SetPrivilegedMode(False);
		
		If Not QueryResult.IsEmpty() Then
			MessageText = NStr("en='Records are registered for mutual settlements with the counterparty in the infobase. Cannot change the settlements accounting dimension.';ru='В базе присутствуют движения по взаиморасчетам с контрагентом. Изменение аналитики учета взаиморасчетов запрещено.'");
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText,,,, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure coordinates the state some attributes of the object depending on the other
//
Procedure BringDataToConsistentState()
	
	If LegalEntityIndividual = Enums.CounterpartyKinds.Individual Then
		
		LegalForm = Catalogs.LegalForms.EmptyRef();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf