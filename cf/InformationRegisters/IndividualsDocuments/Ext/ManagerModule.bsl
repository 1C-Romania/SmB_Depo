#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// The function returns the identity document valid to the specified date
//
// Parameters
// Ind			- individual for which it is
// required to receive the Date document			- date for which it is required to receive document
//
// Return
// value Presentation		- String - identity document presentation
//
Function IdentificationDocument(Ind, Date = Undefined) Export
	
	Query = New Query;
	Query.SetParameter("Individual",	Ind);
	Query.SetParameter("CutoffDate",	Date);
	
	Query.Text =
	"SELECT TOP 1
	|	IndividualsDocuments.Presentation
	|FROM
	|	InformationRegister.IndividualsDocuments AS IndividualsDocuments
	|		INNER JOIN (SELECT
	|			MAX(IndividualsDocuments.Period) AS Period,
	|			IndividualsDocuments.Ind AS Ind
	|		FROM
	|			InformationRegister.IndividualsDocuments AS IndividualsDocuments
	|		WHERE
	|			IndividualsDocuments.IsIdentityDocument
	|			AND IndividualsDocuments.Ind = &Individual
	|			" + ?(Date <> Undefined, "AND IndividualsDocuments.Period <= &CutoffDate", "") + "
	|		
	|		GROUP
	|			BY IndividualsDocuments.Ind)
	|		AS DocumentsSlice ON IndividualsDocuments.Period
	|			= DocumentsSlice.Period AND IndividualsDocuments.Ind
	|			= DocumentsSlice.Ind AND (IndividualsDocuments.IsIdentityDocument)";
	Selection = Query.Execute().Select();
	
	IdentityCard = New Structure("Presentation, IsIdentity");
	
	If Selection.Next() Then
		Return Selection.Presentation;
	EndIf;
	
	Return "";
	
EndFunction

// The function checks whether the specified document kind is an identity document of this individual
//
// Parameters
// Ind			- individual for which it is
// required to receive the DocumentKind document	- the Date identity
// document kind			- date for which it is required to receive document
//
// Return
// value Is		- Boolean - whether the specified document kind is an identity document
//
Function IsPersonID(Ind, DocumentKind, Date) Export
	
	If Ind.IsEmpty() Or DocumentKind.IsEmpty() Or Not ValueIsFilled(Date) Then
		Return False;
	EndIf;
	
	If DocumentKind = Catalogs.IndividualsDocumentsKinds.LocalPassport Then
		Return True;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Individual",	Ind);
	Query.SetParameter("DocumentKind",	DocumentKind);
	Query.SetParameter("CutoffDate",	Date);
	
	Query.Text =
	"SELECT
	|	IndividualsDocuments.DocumentKind
	|FROM
	|	InformationRegister.IndividualsDocuments AS IndividualsDocuments
	|		INNER JOIN (SELECT
	|			MAX(IndividualsDocuments.Period) AS Period,
	|			IndividualsDocuments.Ind AS Ind
	|		FROM
	|			InformationRegister.IndividualsDocuments AS IndividualsDocuments
	|		WHERE
	|			IndividualsDocuments.Ind = &Individual
	|			AND IndividualsDocuments.Period < &CutoffDate
	|			AND IndividualsDocuments.IsIdentityDocument
		
	|		GROUP BY
	|			IndividualsDocuments.Ind) AS DocumentsSlice
	|		ON IndividualsDocuments.Ind = DocumentsSlice.Ind
	|			AND IndividualsDocuments.Period = DocumentsSlice.Period
	|			AND (IndividualsDocuments.DocumentKind = &DocumentKind)";
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function GetDocumentPresentationByIndividual(Individual) Export
	
	If Individual.IsEmpty() Then
		Return NStr("ru = 'Заполнить сведения паспорта (другого документа)'; en = 'Fill passport details (other document)'");
	EndIf;
	
	QueryIndividualDocuments = New Query;
	QueryIndividualDocuments.Text =
	"SELECT TOP 1
	|	IndividualsDocumentsSliceLast.Presentation AS Presentation,
	|	1 AS Priority
	|FROM
	|	InformationRegister.IndividualsDocuments.SliceLast(
	|			,
	|			Ind = &Individual
	|				AND DocumentKind = &DocumentKind) AS IndividualsDocumentsSliceLast
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	IndividualsDocumentsSliceLast.Presentation,
	|	2
	|FROM
	|	InformationRegister.IndividualsDocuments.SliceLast(, Ind = &Individual) AS IndividualsDocumentsSliceLast
	|
	|ORDER BY
	|	Priority";
	QueryIndividualDocuments.SetParameter("Individual", Individual);
	QueryIndividualDocuments.SetParameter("DocumentKind", Catalogs.IndividualsDocumentsKinds.LocalPassport);
	Selection = QueryIndividualDocuments.Execute().Select();
	If Selection.Next() Then
		Return Selection.Presentation;
	Else
		Return NStr("ru = 'Заполнить сведения паспорта (другого документа)'; en = 'Fill passport details (other document)'");
	EndIf;
	
EndFunction

#EndIf