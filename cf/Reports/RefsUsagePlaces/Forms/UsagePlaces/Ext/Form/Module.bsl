// Form accepts parameters:
//
//     RefsSet - Array, ValuesList - items set for analysis on opening. Can be
//                                            a collection of items with field "Reference". If there are items, then report
//     is generated automatically on opening.
//

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	InitializeCustomReportSettings(Parameters);
	
	// And then put it to a form
	Parameters.UserSettings = Report.SettingsComposer.UserSettings;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	Representation = Items.Result.StatePresentation;
	Representation.Visible                      = True;
	Representation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
	Representation.Picture                       = PictureLib.LongOperation48;
	Representation.Text                          = NStr("en='Generating the report...';ru='Отчет формируется...'");
	
	AttachIdleHandler("RunCreation", 0.1, True);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Generate(Command)
	
	RunCreation();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure RunCreation()
	
	ComposeResult(ResultCompositionMode.Background);
	
EndProcedure

// Initializes custom settings of a composer by passed parameters.
//
&AtServer
Procedure InitializeCustomReportSettings(Val DataParameters)
	NewParameters = New Map;
	
	// RefsSet
	RefsSet = New ValueList;
	If DataParameters.Property("RefsSet") Then
		CurrentParameter = DataParameters.RefsSet;
		
		ParameterType = TypeOf(CurrentParameter);
		If ParameterType = Type("Array") Then
			RefsSet.LoadValues(CurrentParameter);
			
		ElsIf ParameterType = Type("ValueList") Then
			RefsSet.LoadValues(CurrentParameter.UnloadValues());
			
		Else
			ThisIsEnumerationType = False;
			Try
				// Enumeration
				For Each Item IN CurrentParameter Do
					ThisIsEnumerationType = True;
					Break;
				EndDo;
			Except
				ThisIsEnumerationType = False;
			EndTry;
			
			If ThisIsEnumerationType Then
				For Each Item IN CurrentParameter Do
					RefsSet.Add(Item.Ref);
				EndDo;
			EndIf;
		EndIf;
		
		NewParameters.Insert(New DataCompositionParameter("RefsSet"), RefsSet);
	EndIf;
	
	// Set in custom fields.
	For Each Item IN Report.SettingsComposer.UserSettings.Items Do
		Value = NewParameters[Item.Parameter];
		If Value<>Undefined Then
			Item.Use = True;
			Item.Value      = Value;
		EndIf;
	EndDo;
EndProcedure

#EndRegion














