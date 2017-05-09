#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		FillByCounterparty(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		FillByStructure(FillingData);
		
	EndIf;
	
	FillByDefault();
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Prices kind.
	If ValueIsFilled(DiscountMarkupKind) Then
		CheckedAttributes.Add("PriceKind");
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If DeletionMark Then
		
		CounterpartyAttributesValues = CommonUse.ObjectAttributesValues(Owner, "DeletionMark, ContractByDefault");
		
		If Not CounterpartyAttributesValues.DeletionMark And CounterpartyAttributesValues.ContractByDefault = Ref Then
			MessageText = NStr("ru='Договор контрагента, установленный в качестве основного, не может быть помечен на удаление.'; en = 'The counterparty contract, established as the main, can not be marked for deletion.'");
			CommonUseClientServer.MessageToUser(MessageText, Ref,,, Cancel);
		EndIf;
		
	EndIf;
	
	Query = New Query(
	"SELECT
	|	CounterpartyContracts.Ref
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|WHERE
	|	CounterpartyContracts.Ref <> &Ref
	|	AND CounterpartyContracts.Owner = &Owner
	|	AND Not CounterpartyContracts.Owner.DoOperationsByContracts");
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Owner", Owner);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		MessageText = NStr("en = 'Contracts are not accounted for the counterparty.'; ru = 'Для контрагента не ведется учет по договорам.'");
		SmallBusinessServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			,
			Cancel
		);
	EndIf;
	
	If ValueIsFilled(Ref) Then
		AdditionalProperties.Insert("DeletionMark", Ref.DeletionMark);
	EndIf;
	
EndProcedure

#EndRegion

#Region FillingProcedures

Procedure FillByCounterparty(FillingData)
	
	AttributesValues	= CommonUse.ObjectAttributesValues(FillingData, "Customer,Supplier,OtherRelationship, BankAccountByDefault");
	
	CompanyByDefault = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
	If Not ValueIsFilled(CompanyByDefault) Then
		CompanyByDefault = Catalogs.Companies.MainCompany;
	EndIf;
	
	Description				= NStr("ru = 'Основной договор'; en = 'Main contract'");
	SettlementsCurrency		= Constants.NationalCurrency.Get();
	Company					= CompanyByDefault;
	ContractKind			= Enums.ContractKinds.WithCustomer;
	CashFlowItem			= Catalogs.CashFlowItems.PaymentFromCustomers;
	If AttributesValues.Supplier And Not AttributesValues.Customer Then
		ContractKind		= Enums.ContractKinds.WithVendor;
		CashFlowItem		= Catalogs.CashFlowItems.PaymentToVendor;
	ElsIf AttributesValues.OtherRelationship And Not AttributesValues.Customer And Not AttributesValues.Supplier Then
		ContractKind		= Enums.ContractKinds.Other;
		CashFlowItem		= Catalogs.CashFlowItems.Other;
	EndIf;
	PriceKind				= Catalogs.PriceKinds.GetMainKindOfSalePrices();
	Owner					= FillingData;
	VendorPaymentDueDate	= Constants.VendorPaymentDueDate.Get();
	CustomerPaymentDueDate	= Constants.CustomerPaymentDueDate.Get(); 
	CounterpartyBankAccount	= AttributesValues.BankAccountByDefault;
	Status					= Enums.CounterpartyContractStatuses.Active;
	
EndProcedure

Procedure FillByStructure(FillingData)

	If FillingData.Property("Owner") And ValueIsFilled(FillingData.Owner) Then
		
		FillByCounterparty(FillingData.Owner);
		
	EndIf;
	

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
	
	If Not ValueIsFilled(Department) Then
		Department = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainDepartment");
		If Not ValueIsFilled(Department) Then
			Department	= Catalogs.StructuralUnits.MainDepartment;	
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(BusinessActivity) Then
		BusinessActivity	= Catalogs.BusinessActivities.MainActivity;	
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
