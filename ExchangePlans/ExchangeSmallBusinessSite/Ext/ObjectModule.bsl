#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeDelete(Cancel)
	
	Task = ExchangeWithSiteScheduledJobs.FindJob(ScheduledJobID);
	If Task <> Undefined Then
		ExchangeWithSiteScheduledJobs.DeleteJob(Task);
	EndIf;
	ScheduledJobID = Undefined;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If IsBlankString(Code) Then
		SetNewCode();
	EndIf;
	
	If IsBlankString(Description) Then
		GenerateDescription()
	EndIf;
	
	If Not ProductsExchange
		AND Not OrdersExchange Then
		
		Cancel = True;
		Message = NStr("en = 'Exchange mode is not selected!'");
		Field = "ProductsExchange";
		CommonUseClientServer.MessageToUser(Message, ThisObject, Field);
		
	EndIf;

	AddCheckedAttributes(CheckedAttributes);
	
EndProcedure

Procedure OnCopy(CopiedObject)
	Code = "";
	ScheduledJobID = UNDEFINED;
EndProcedure

#EndRegion

#Region ProgramInterface

// Generates object unique description
// 
// Parameters:
// no
// 
// Returns:
// no
//
Procedure GenerateDescription() Export
	
	If ProductsExchange AND OrdersExchange Then
		
		Prefix = NStr("en = 'Products and orders exchange'");
		
	ElsIf OrdersExchange Then
		
		Prefix = NStr("en = 'Orders exchange'");
		
	Else
		
		Prefix = NStr("en = 'Products export'");
		
	EndIf;
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	MAX(ExchangeSmallBusinessSite.Description) AS Description
	|FROM
	|	ExchangePlan.ExchangeSmallBusinessSite AS ExchangeSmallBusinessSite
	|WHERE
	|	ExchangeSmallBusinessSite.Description LIKE &Pattern
	|
	|HAVING
	|	(NOT MAX(ExchangeSmallBusinessSite.Description) IS NULL )";
	
	Query.SetParameter("Pattern", Prefix + "%");
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Description = Prefix;
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	Suffix = Right(TrimAll(Selection.Description), 4);
	
	Try
		SuffixByNumber = Number(Suffix);
	Except
		Description = Prefix + " 0001";
		Return;
	EndTry;
	
	Description = Prefix + " " + Format(SuffixByNumber + 1, "ND=4; NLZ=; NG=");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure AddCheckedAttributes(CheckedAttributes)
	
	If ExportToSite Then
		
		CheckedAttributes.Add("SiteAddress");
		CheckedAttributes.Add("UserName");
		
	Else
		
		CheckedAttributes.Add("ExportDirectory");
		
	EndIf;

	If OrdersExchange Then
		
		If Not ExportToSite Then
			CheckedAttributes.Add("ImportFile");
		EndIf;
		
		CheckedAttributes.Add("CounterpartiesIdentificationMethod");
		
		If CounterpartiesIdentificationMethod = Enums.CounterpartiesIdentificationMethods.PredefinedValue Then
			CheckedAttributes.Add("CounterpartyToSubstituteIntoOrders");
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf