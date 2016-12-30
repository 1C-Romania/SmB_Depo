#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	TextSeries				= NStr("en=', series: %1';ru=', серия: %1'");
	TextNumber				= NStr("en=',  No.%1';ru=',  No.%1'");
	TextIssuanceDate			= NStr("en=', issued: %1 year';ru=', выдан: %1 года'");
	TextValidityPeriod		= NStr("en=', valid till: %1 year';ru=', действует до: %1 года'");
	TextDepartmentCode	= NStr("en=', div. No.%1';ru=', № подр. %1'");
	
	For Each Record IN ThisObject Do
		If Record.DocumentKind.IsEmpty() Then
			Record.Presentation = "";
			
		Else
			Record.Presentation = ""
				+ Record.DocumentKind
				+ ?(ValueIsFilled(Record.Series), StringFunctionsClientServer.PlaceParametersIntoString(TextSeries, Record.Series), "")
				+ ?(ValueIsFilled(Record.Number), StringFunctionsClientServer.PlaceParametersIntoString(TextNumber, Record.Number), "")
				+ ?(ValueIsFilled(Record.IssueDate), StringFunctionsClientServer.PlaceParametersIntoString(TextIssuanceDate, Format(Record.IssueDate,"DF=dd MMMM yyyy'")), "")
				+ ?(ValueIsFilled(Record.ValidityPeriod), StringFunctionsClientServer.PlaceParametersIntoString(TextValidityPeriod, Format(Record.ValidityPeriod,"DF=dd MMMM yyyy'")), "")
				+ ?(ValueIsFilled(Record.WhoIssued), ", " + Record.WhoIssued, "")
				+ ?(ValueIsFilled(Record.DepartmentCode) AND Record.DocumentKind = Catalogs.IndividualsDocumentsKinds.LocalPassport, StringFunctionsClientServer.PlaceParametersIntoString(TextDepartmentCode, Record.DepartmentCode), "");
			
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
	
	MessageText = NStr("en='The ID of %2 has been entered already as of 1%.';ru='На %1 у физлица %2 уже введен документ, удостоверяющий личность.'");
	
	While Selection.Next() Do
		Cancel = True;
		
		CommonUseClientServer.MessageToUser(StringFunctionsClientServer.PlaceParametersIntoString(MessageText, Format(Selection.Period, "DLF=D"), Selection.Ind));
	EndDo;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each Record IN ThisObject Do
		RecordStructure = New Structure("Period, Ind, DocumentKind");
		FillPropertyValues(RecordStructure, Record);
		
		RecordKey = InformationRegisters.IndividualsDocuments.CreateRecordKey(RecordStructure);
		
		If Not IsBlankString(Record.Series) Then
			ErrorText = "";
			Cancel = Not IndividualsDocumentsClientServer.DocumentSeriesSpecifiedProperly(Record.DocumentKind, Record.Series, ErrorText) Or Cancel;
			If Not IsBlankString(ErrorText) Then
				CommonUseClientServer.MessageToUser(ErrorText, RecordKey, "Record.Series");
			EndIf;
		EndIf;
		
		If Not IsBlankString(Record.Number) Then
			ErrorText = "";
			Cancel = Not IndividualsDocumentsClientServer.DocumentNumberSpecifiedProperly(Record.DocumentKind, Record.Number, ErrorText) Or Cancel;
			If Not IsBlankString(ErrorText) Then
				CommonUseClientServer.MessageToUser(ErrorText, RecordKey, "Record.Number");
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure


#EndIf