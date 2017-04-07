#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		// Program filling by method Fill()
		
		StandardProcessing = False;
		
		CompanyByDefault = SmallBusinessReUse.GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainCompany");
		If Not ValueIsFilled(CompanyByDefault) Then
			CompanyByDefault = Catalogs.Companies.MainCompany;
		EndIf;
		
		Description				= "Main contract";
		SettlementsCurrency		= Constants.NationalCurrency.Get();
		Company					= CompanyByDefault;
		ContractKind			= Enums.ContractKinds.WithCustomer;
		PriceKind				= Catalogs.PriceKinds.GetMainKindOfSalePrices();
		Owner					= FillingData;
		VendorPaymentDueDate	= Constants.VendorPaymentDueDate.Get();
		CustomerPaymentDueDate	= Constants.CustomerPaymentDueDate.Get();
		
	EndIf;
	
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

#EndIf
