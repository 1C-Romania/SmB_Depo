#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Payment calendar table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.PaymentReceiptPlan - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.CashAssetsType AS CashAssetsType,
	|	DocumentTable.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	CASE
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN DocumentTable.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	&Ref AS InvoiceForPayment,
	|	DocumentTable.DocumentCurrency AS Currency,
	|	-DocumentTable.DocumentAmount AS Amount
	|FROM
	|	Document.CashTransferPlan AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.CashFlowItem,
	|	DocumentTable.CashAssetsTypePayee,
	|	DocumentTable.PaymentConfirmationStatus,
	|	CASE
	|		WHEN DocumentTable.CashAssetsTypePayee = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCashPayee
	|		WHEN DocumentTable.CashAssetsTypePayee = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN DocumentTable.BankAccountPayee
	|		ELSE UNDEFINED
	|	END,
	|	&Ref,
	|	DocumentTable.DocumentCurrency,
	|	DocumentTable.DocumentAmount
	|FROM
	|	Document.CashTransferPlan AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure // GenerateTablePaymentCalendar()

// Creates a document data table.
//
// Parameters:
// DocumentRef - DocumentRef.PaymentReceiptPlan - Current
// document StructureAdditionalProperties - AdditionalProperties - Additional properties of the document
//	
Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export

	GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf