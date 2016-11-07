#Region ServiceProceduresAndFunctions

// Function defines the default cash.
//
// Returns cash register if one cash is found.
// Returns Undefined if cash is not found or there are cashes more than one.
//
// Returns:
// CatalogRef.CashRegisters - Found cash register
//
&AtServer
Function GetCashRegisterAndTerminalDefault() Export
	
	ParametersStructure = New Structure("CashCR, POSTerminal, POSTerminalQuantity, Company, StructuralUnit", 
		Catalogs.CashRegisters.EmptyRef(), Catalogs.POSTerminals.EmptyRef(), 0);
	
	Query = New Query(
	"SELECT TOP 2
	|	CashRegisters.Ref AS CashCR,
	|	CashRegisters.StructuralUnit,
	|	CashRegisters.Owner AS Company
	|INTO CashRegisters
	|FROM
	|	Catalog.CashRegisters AS CashRegisters
	|WHERE
	|	Not CashRegisters.DeletionMark
	|	AND CashRegisters.CashCRType = &CashCRType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	POSTerminals.Ref AS POSTerminal,
	|	POSTerminals.PettyCash
	|FROM
	|	Catalog.POSTerminals AS POSTerminals
	|		INNER JOIN CashRegisters AS CashRegisters
	|		ON POSTerminals.PettyCash = CashRegisters.CashCR
	|WHERE
	|	Not POSTerminals.DeletionMark
	|	AND POSTerminals.PettyCash.CashCRType = &CashCRType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CashRegisters.CashCR,
	|	CashRegisters.StructuralUnit,
	|	CashRegisters.Company
	|FROM
	|	CashRegisters AS CashRegisters");
	
	Query.SetParameter("CashCRType", Enums.CashCRTypes.FiscalRegister);
	
	MResults = Query.ExecuteBatch();
	Selection = MResults[2].Select();
	CashCRQuantity = Selection.Count();
	If CashCRQuantity = 1 
	   AND Selection.Next() Then
	
		ParametersStructure.CashCR = Selection.CashCR;
		ParametersStructure.StructuralUnit = Selection.StructuralUnit;
		ParametersStructure.Company = Selection.Company;
		
	Else
		
		ParametersStructure.CashCR = Undefined;
		
	EndIf;
	
	If CashCRQuantity = 1 Then
		VT_AT = MResults[1].Unload();
		
		ETCashesDefault = VT_AT.FindRows(New Structure("PettyCash", ParametersStructure.CashCR));
		
		ParametersStructure.POSTerminalQuantity = ETCashesDefault.Count();
		If ETCashesDefault.Count() = 1 Then
			
			ParametersStructure.POSTerminal = ETCashesDefault[0].POSTerminal;
			
		Else
			
			ParametersStructure.POSTerminal = Undefined;
			
		EndIf;
	Else
		ParametersStructure.POSTerminal = Undefined;
	EndIf;
	
	Return ParametersStructure;

EndFunction // GetCashDefault()

#EndRegion

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ParametersStructure = GetCashRegisterAndTerminalDefault();
	
	EquipmentManagerClient.RefreshClientWorkplace();
	
	If ParametersStructure.CashCR <> Undefined AND 
		(ParametersStructure.POSTerminal <> Undefined Or ParametersStructure.POSTerminalQuantity = 0) Then
		
		BATCHParameters = New Structure;
		BATCHParameters.Insert("Company", ParametersStructure.Company);
		BATCHParameters.Insert("CashCR", ParametersStructure.CashCR);
		BATCHParameters.Insert("StructuralUnit", ParametersStructure.StructuralUnit);
		BATCHParameters.Insert("POSTerminal", ParametersStructure.POSTerminal);
		
		OpenForm("Document.ReceiptCR.Form.DocumentForm_CWP", BATCHParameters);
		
	Else
		
		OpenForm("Document.ReceiptCR.Form.DocumentForm_CWP_WindowPettyCashSelection", New Structure("ParametersStructure", ParametersStructure), CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window, CommandExecuteParameters.URL);
		
	EndIf;
	
EndProcedure
