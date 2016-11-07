#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Event handler procedure ChoiceDataGetProcessor.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Not (Parameters.Property("SearchString") AND ValueIsFilled(Parameters.SearchString)) Then
		Return
	EndIf;
	
	StandardProcessing = False;
	ValueArray = New Array;
	
	For Counter = 1 To 5 Do
		If Parameters.Property("TimeKind" + Counter) AND ValueIsFilled(Parameters["TimeKind" + Counter]) Then		
			ValueArray.Add(Parameters["TimeKind" + Counter]);
		EndIf;
	EndDo;
	
	Query = New Query("SELECT
				  |	WorkingHoursKinds.Ref
				  |FROM
				  |	Catalog.WorkingHoursKinds AS WorkingHoursKinds
				  |WHERE
				  |	Not (WorkingHoursKinds.Ref IN(&ValueArray))
				  |
				  |GROUP BY
				  |	WorkingHoursKinds.Ref
				  |
				  |HAVING
				  |	SubString(WorkingHoursKinds.Description, 1, &SubstringLength) LIKE &SearchString
				  |
				  |ORDER BY
				  |	WorkingHoursKinds.Description");
				  
	Query.SetParameter("ValueArray", ValueArray);
	Query.SetParameter("SearchString", Parameters.SearchString);
	Query.SetParameter("SubstringLength", StrLen(Parameters.SearchString));
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		ChoiceData = New ValueList;
		Selection = Result.Select();
		While Selection.Next() Do
			ChoiceData.Add(Selection.Ref);
		EndDo;
	EndIf;
	
EndProcedure // ChoiceDataGetProcessor()

#EndIf