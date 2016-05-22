#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Procedure CheckDuplicatesOfRows(Cancel) Export 
	
	Query = New Query();
	
	Query.Text = 
	"SELECT
	|	ImportingList.LineNumber AS LineNumber,
	|	ImportingList.Description AS Description
	|INTO DocumentTable
	|FROM
	|	&ImportingList AS ImportingList
	|WHERE
	|	ImportingList.ImportingFlag
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(ImportingList1.LineNumber) AS LineNumber,
	|	ImportingList1.Description AS Description
	|FROM
	|	DocumentTable AS ImportingList1
	|		INNER JOIN DocumentTable AS ImportingList2
	|		ON ImportingList1.LineNumber <> ImportingList2.LineNumber
	|			AND ImportingList1.Description = ImportingList2.Description
	|
	|GROUP BY
	|	ImportingList1.Description
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("ImportingList", ImportingList);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		QueryResultSelection = QueryResult.Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr(
				"en = 'Products and services ""%Description%"" in string %LineNumber% is specified repeatedly.'"
			);
			MessageText = StrReplace(MessageText, "%LineNumber%", QueryResultSelection.LineNumber);
			MessageText = StrReplace(MessageText, "%Description%", QueryResultSelection.Description);
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"ImportingList",
				QueryResultSelection.LineNumber,
				"Description",
				Cancel
			);
		EndDo;
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf