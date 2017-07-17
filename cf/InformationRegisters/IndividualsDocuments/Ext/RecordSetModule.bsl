#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	TextSeries			= NStr("en=', series: %1';			ru=', серия: %1'");
	TextNumber			= NStr("en=', No.%1';				ru=', № %1'");
	TextIssuanceDate	= NStr("en=', issued: %1';ru=', выдан: %1 года'");
	TextValidityPeriod	= NStr("en=', valid till: %1';ru=', действует до: %1 года'");
	TextDepartmentCode	= NStr("en=', dep. No.%1';ru=', № подр. %1'");
	
	For Each Record IN ThisObject Do
		If Record.DocumentKind.IsEmpty() Then
			Record.Presentation = "";
			
		Else
			Record.Presentation = ""
				+ Record.DocumentKind
				+ ?(ValueIsFilled(Record.Series), StringFunctionsClientServer.SubstituteParametersInString(TextSeries, Record.Series), "")
				+ ?(ValueIsFilled(Record.Number), StringFunctionsClientServer.SubstituteParametersInString(TextNumber, Record.Number), "")
				+ ?(ValueIsFilled(Record.IssueDate), StringFunctionsClientServer.SubstituteParametersInString(TextIssuanceDate, Format(Record.IssueDate,"DF=dd MMMM yyyy'")), "")
				+ ?(ValueIsFilled(Record.ValidityPeriod), StringFunctionsClientServer.SubstituteParametersInString(TextValidityPeriod, Format(Record.ValidityPeriod,"DF=dd MMMM yyyy'")), "")
				+ ?(ValueIsFilled(Record.WhoIssued), ", " + Record.WhoIssued, "")
				+ ?(ValueIsFilled(Record.DepartmentCode) AND Record.DocumentKind = Catalogs.IndividualsDocumentsKinds.LocalPassport, StringFunctionsClientServer.SubstituteParametersInString(TextDepartmentCode, Record.DepartmentCode), "");
			
		EndIf;
	EndDo;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("DocumentsTable",	Unload(, "Ind, Period, IsIdentityDocument"));
	
	Query.Text =
	"SELECT
	|	DocumentsTable.Ind AS Ind,
	|	DocumentsTable.Period AS Period
	|INTO TU_Documents
	|FROM
	|	&DocumentsTable AS DocumentsTable
	|WHERE
	|	DocumentsTable.IsIdentityDocument
	|
	|INDEX BY
	|	Ind,
	|	Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IndividualsDocuments.Ind AS Ind,
	|	IndividualsDocuments.Period AS Period,
	|	COUNT(IndividualsDocuments.Ind) AS DocumentsCount
	|FROM
	|	InformationRegister.IndividualsDocuments AS IndividualsDocuments
	|		INNER JOIN TU_Documents AS DocumentsSlice
	|		ON IndividualsDocuments.Period = DocumentsSlice.Period
	|			AND IndividualsDocuments.Ind = DocumentsSlice.Ind
	|			AND (IndividualsDocuments.IsIdentityDocument)
	|
	|GROUP BY
	|	IndividualsDocuments.Ind,
	|	IndividualsDocuments.Period
	|
	|HAVING
	|	COUNT(IndividualsDocuments.Ind) > 1";
	Selection = Query.Execute().Select();
	
	MessageText = NStr("en='ID document of individual %2 has been already entered as of 1%.';ru='На %1 у физлица %2 уже введен документ, удостоверяющий личность.'");
	
	While Selection.Next() Do
		Cancel = True;
		
		CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(MessageText, Format(Selection.Period, "DLF=D"), Selection.Ind));
	EndDo;
	
EndProcedure

#EndIf