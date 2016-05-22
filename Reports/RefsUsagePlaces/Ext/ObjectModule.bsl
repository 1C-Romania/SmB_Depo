#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	StandardProcessing = False;
	
	// Regenerate header by a set of references.
	Settings = SettingsComposer.GetSettings();
	RefsSet = Settings.DataParameters.FindParameterValue( New DataCompositionParameter("RefsSet") );
	If RefsSet <> Undefined Then
		RefsSet = RefsSet.Value;
	EndIf;
	Title = TitleByLinksSet(RefsSet);
	SettingsComposer.FixedSettings.OutputParameters.SetParameterValue("Title", Title);
	
	CompositionProcessor = CompositionProcessor(DetailsData);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.Output(CompositionProcessor);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function CompositionProcessor(DetailsData = Undefined, GeneratorType = "DataCompositionTemplateGenerator")
	
	Settings = SettingsComposer.GetSettings();
	
	// References list from parameters.
	ParameterValue = Settings.DataParameters.FindParameterValue( New DataCompositionParameter("RefsSet") ).Value;
	ValueType = TypeOf(ParameterValue);
	If ValueType = Type("ValueList") Then
		RefArray = ParameterValue.UnloadValues();
	ElsIf ValueType = Type("Array") Then
		RefArray = ParameterValue;
	Else
		RefArray = New Array;
		If ParameterValue <>Undefined Then
			RefArray.Add(ParameterValue);
		EndIf;
	EndIf;
	
	// Parameters of output from fixed parameters.
	For Each OutputParameter IN SettingsComposer.FixedSettings.OutputParameters.Items Do
		If OutputParameter.Use Then
			Item = Settings.OutputParameters.FindParameterValue(OutputParameter.Parameter);
			If Item <> Undefined Then
				Item.Use = True;
				Item.Value      = OutputParameter.Value;
			EndIf;
		EndIf;
	EndDo;
	
	// Data source tables
	UsagePlaces = CommonUse.UsagePlaces(RefArray);
	
	// Check that we have all references.
	For Each Refs IN RefArray Do
		If UsagePlaces.Find(Refs, "Ref") = Undefined Then
			Additionally = UsagePlaces.Add();
			Additionally.Ref = Refs;
			Additionally.AuxiliaryData = True;
		EndIf;
	EndDo;
		
	ExternalData = New Structure;
	ExternalData.Insert("UsagePlaces", UsagePlaces);
	
	// Execution
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData, , Type(GeneratorType));
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(Template, ExternalData, DetailsData);
	
	Return CompositionProcessor;
EndFunction

Function TitleByLinksSet(Val RefsSet)
	Result = Undefined;
	
	If TypeOf(RefsSet) = Type("ValueList") Then
		TotalRefs = RefsSet.Count() - 1;
		If TotalRefs >= 0 Then
		
			SameType = True;
			FirstRefType = TypeOf(RefsSet[0].Value);
			For Position = 0 To TotalRefs Do
				If TypeOf(RefsSet[Position].Value) <> FirstRefType Then
					SameType = False;
					Break;
				EndIf;
			EndDo;
			
			If SameType Then
				Result = StrReplace(NStr("en = 'Usage locations %1'"), "%1", 
					RefsSet[0].Value.Metadata().Presentation() );
			EndIf;
		EndIf;
	EndIf;
	
	If Result = Undefined Then
		Result = NStr("en = 'Item usage locations'");
	EndIf;
	
	Return Result;
EndFunction

#EndRegion

#EndIf