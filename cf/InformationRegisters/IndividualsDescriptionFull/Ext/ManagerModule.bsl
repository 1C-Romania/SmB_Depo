#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function returns full name by specified individual
//
Function IndividualDescriptionFull(RelevanceDate, Ind) Export
	
	Query = New Query(
	"SELECT
	|	IndividualsDescriptionFullSliceLast.Surname,
	|	IndividualsDescriptionFullSliceLast.Name,
	|	IndividualsDescriptionFullSliceLast.Patronymic
	|FROM
	|	InformationRegister.IndividualsDescriptionFull.SliceLast(&RelevanceDate, Ind = &Ind) AS IndividualsDescriptionFullSliceLast");
	
	Query.SetParameter("RelevanceDate", RelevanceDate);
	Query.SetParameter("Ind", Ind);
	
	QueryResult	= Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		Return "";
		
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return SmallBusinessServer.GetSurnameNamePatronymic(Selection.Surname, Selection.Name, Selection.Patronymic, True);
	
EndFunction //IndividualFullName()

#EndRegion

#EndIf