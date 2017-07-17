#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Procedure ExecuteMonthEnd(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	CurMonth = ParametersStructure.CurMonth;
	CurYear = ParametersStructure.CurYear;
	Company = ParametersStructure.Company;
	OperationArray = ParametersStructure.OperationArray;
	
	StructureOfCurrentDocuments = CancelMonthEnd(ParametersStructure);
	
	If ParametersStructure.ExecuteCalculationOfDepreciation Then
		
		If ValueIsFilled(StructureOfCurrentDocuments.DocumentFixedAssetsDepreciation) Then
			
			DocObject = StructureOfCurrentDocuments.DocumentFixedAssetsDepreciation.GetObject();
			If DocObject.DeletionMark Then
				DocObject.SetDeletionMark(False);
			EndIf;
			
		Else
			
			DocObject = Documents.FixedAssetsDepreciation.CreateDocument();
			DocObject.Company = Company;
			DocObject.Date = EndOfMonth(Date(CurYear, CurMonth, 1));
			DocObject.Comment = NStr("en='#Created automatically using month-end closing wizard.';ru='#Создан автоматически, помощником закрытия месяца.'");
			
		EndIf;
		
		DocObject.Write(DocumentWriteMode.Posting);
		
	EndIf;
	
	DocumentArrayMC = StructureOfCurrentDocuments.DocumentMonthEnd;
	ArraySizeDocumentsZM = DocumentArrayMC.Count() - 1;
	OperationArraySize = OperationArray.Count() - 1;
	
	For Iterator = 0 To OperationArraySize Do
		
		Operation = OperationArray[Iterator];
		DocumentClosingMonth = ?(Iterator <= ArraySizeDocumentsZM, DocumentArrayMC[Iterator], Undefined);
		RunOperationClosingMonth(ParametersStructure, Operation, DocumentClosingMonth);
		
	EndDo;
	
EndProcedure

Function CancelMonthEnd(ParametersStructure) Export
	
	CurMonth = ParametersStructure.CurMonth;
	CurYear = ParametersStructure.CurYear;
	Company = ParametersStructure.Company;
	
	ReturnStructure = New Structure("DocumentMonthEnd, DocumentFixedAssetsDepreciation");
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	MonthEnd.Date AS Date,
	|	MonthEnd.Ref AS Ref
	|FROM
	|	Document.MonthEnd AS MonthEnd
	|WHERE
	|	YEAR(MonthEnd.Date) = &Year
	|	AND MONTH(MonthEnd.Date) = &Month
	|	AND MonthEnd.Company = &Company
	|
	|ORDER BY
	|	Date,
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FixedAssetsDepreciation.Date AS Date,
	|	FixedAssetsDepreciation.Ref AS Ref
	|FROM
	|	Document.FixedAssetsDepreciation AS FixedAssetsDepreciation
	|WHERE
	|	YEAR(FixedAssetsDepreciation.Date) = &Year
	|	AND MONTH(FixedAssetsDepreciation.Date) = &Month
	|	AND FixedAssetsDepreciation.Company = &Company
	|
	|ORDER BY
	|	Date,
	|	Ref";
	
	Query.SetParameter("Year", CurYear);
	Query.SetParameter("Month", CurMonth);
	Query.SetParameter("Company", Company);
	
	QueryResult = Query.ExecuteBatch();
	
	DocSelection = QueryResult[1].Select();
	While DocSelection.Next() Do
		
		DocObject = DocSelection.Ref.GetObject();
		If DocObject.DeletionMark Then
			DocObject.SetDeletionMark(False);
		EndIf;
		
		DocObject.Write(DocumentWriteMode.UndoPosting);
		ReturnStructure.DocumentFixedAssetsDepreciation = DocSelection.Ref;
		
	EndDo;
	
	ReturnStructure.DocumentMonthEnd = New Array;
	
	DocSelection = QueryResult[0].Select();
	While DocSelection.Next() Do
		
		DocObject = DocSelection.Ref.GetObject();
		If DocObject.DeletionMark Then
			DocObject.SetDeletionMark(False);
		EndIf;
		
		DocObject.Write(DocumentWriteMode.UndoPosting);
		ReturnStructure.DocumentMonthEnd.Add(DocSelection.Ref);
		
	EndDo;
	
	Return ReturnStructure;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure RunOperationClosingMonth(ParametersStructure, Operation, DocumentClosingMonth)
	
	CurMonth = ParametersStructure.CurMonth;
	CurYear = ParametersStructure.CurYear;
	Company = ParametersStructure.Company;
	
	If DocumentClosingMonth = Undefined Then
		
		DocObject = Documents.MonthEnd.CreateDocument();
		DocObject.Company = Company;
		DocObject.Date = EndOfMonth(Date(CurYear, CurMonth, 1));
		DocObject.Comment = NStr("en='#Created automatically using month-end closing wizard.';ru='#Создан автоматически, помощником закрытия месяца.'");
		
	Else
		
		DocObject = DocumentClosingMonth.GetObject();
		
		If DocObject.DeletionMark Then
			DocObject.SetDeletionMark(False);
		EndIf;
		
		DocObject.DirectCostCalculation = False;
		DocObject.CostAllocation = False;
		DocObject.ActualCostCalculation = False;
		DocObject.FinancialResultCalculation = False;
		DocObject.ExchangeDifferencesCalculation = False;
		DocObject.RetailCostCalculationAccrualAccounting = False;
		
	EndIf;
	
	DocObject[Operation] = True;
	DocObject.Write(DocumentWriteMode.Posting);
	
EndProcedure

#EndRegion

#EndIf