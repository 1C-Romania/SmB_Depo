////////////////////////////////////////////////////////////////////////////////
// The Search and delete duplicates subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Opens the form of joining of catalogs items, plans of characteristics kinds, calculations kinds and accounts.
//
// Parameters:
//     CombinedItems - FormTable, Array, ValuesList - list of items for combining.
//                            You can also transfer a custom collection of items with the Reference attribute.
//
Procedure CombineSelected(Val CombinedItems) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("RefsSet", RefArray(CombinedItems));
	OpenForm("DataProcessor.ReplaceAndCombineElements.Form.CombineElements", FormParameters); 
	
EndProcedure

// Opens the form of replacement and removal of catalogs items, plans of characteristics kinds, calculations kinds and accounts.
//
// Parameters:
//     ReplacedItems - FormTable, Array, ValuesList - list of items for replacement and removal.
//                          You can also transfer a custom collection of items with the Reference attribute.
//
Procedure ReplaceSelected(Val ReplacedItems) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("RefsSet", RefArray(ReplacedItems));
	FormParameters.Insert("OpenByScenario");
	OpenForm("DataProcessor.ReplaceAndCombineElements.Form.ReplacementElements", FormParameters); 
	
EndProcedure

// Opens the report about locations of references usage.
// The report does not include minor data, such as records sets with leading measurement etc.
//
// Parameters:
//     Items - FormTable, Array, ValuesList - List of items for analysis.
//         You can also transfer a custom collection of items with the Reference attribute.
//     OpenParameters - Structure - Optional. Parameters of the form opening. Consists of optional fields.
//         Owner, Uniqueness, Window, 
//         NavigationRef, ClosingAlertDescription, WindowOpeningMode corresponding to the parameters of the OpenForm function.
// 
Procedure ShowUsagePlacess(Val Items, Val OpenParameters = Undefined) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("RefsSet", RefArray(Items));
	
	FormOpenParameters = New Structure("Owner, Uniqueness, Window,  NavigationRef, ClosingAlertDescription, WindowOpeningMode");
	If OpenParameters <> Undefined Then
		FillPropertyValues(FormOpenParameters, OpenParameters);
	EndIf;
		
	OpenForm("Report.RefsUsagePlaces.Form", FormParameters,
		FormOpenParameters.Owner, FormOpenParameters.Uniqueness, FormOpenParameters.Window, 
		FormOpenParameters.URL, FormOpenParameters.OnCloseNotifyDescription, 
		FormOpenParameters.WindowOpeningMode
	); 
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function RefArray(Val Items)
	
	ParameterType = TypeOf(Items);
	
	If TypeOf(Items) = Type("FormTable") Then
		Refs = New Array;
		For Each Item IN Items.SelectedRows Do
			RowData = Items.RowData(Item);
			If RowData <> Undefined Then
				Refs.Add(RowData.Ref);
			EndIf;
		EndDo;
		
	ElsIf ParameterType = Type("ValueList") Then
		Refs = New Array;
		For Each Item IN Items Do
			Refs.Add(Item.Value);
		EndDo;
		
	Else
		Refs = Items;
		
	EndIf;
	
	Return Refs;
EndFunction

#EndRegion
