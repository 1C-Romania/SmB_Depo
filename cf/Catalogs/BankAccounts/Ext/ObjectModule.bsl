#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Or TypeOf(FillingData) = Type("CatalogRef.Companies") Then
		
		StandardProcessing = False;
		
		Owner = FillingData;
		CashCurrency = Constants.NationalCurrency.Get();
		GLAccount = ChartsOfAccounts.Managerial.Bank;
		AccountType = "Current";
		MonthOutputOption = Enums.MonthOutputTypesInDocumentDate.Number;
		
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If TypeOf(Owner) = Type("CatalogRef.Companies") Then
		CheckedAttributes.Add("GLAccount");
	EndIf;
	
EndProcedure // FillCheckProcessing()

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ClearAttributeMainBankAccount();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure GenerateDescription() Export
	
	Description = StrTemplate(
		NStr("ru = '%1, в %2'; en = '%1, in %2'"),
		TrimAll(AccountNo),
		Bank);
	
EndProcedure

Procedure ClearAttributeMainBankAccount()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Counterparties.Ref AS Ref
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.BankAccountByDefault = &BankAccount
		|
		|UNION ALL
		|
		|SELECT
		|	Companies.Ref
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.BankAccountByDefault = &BankAccount";
	
	Query.SetParameter("BankAccount", Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		CatalogObject = Selection.Ref.GetObject();
		CatalogObject.BankAccountByDefault = Undefined;
		CatalogObject.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf