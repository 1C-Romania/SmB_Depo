#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	// Setting mandatory parameters.
	DataParameters = New Structure;
	DataParameters.Insert("custom", SettingsComposer.GetSettings().DataParameters);
	DataParameters.Insert("Current",          SettingsComposer.Settings.DataParameters);
	
	SetRequiredParameter("Users", "SpecifiedUsers", False, True, DataParameters);
	SetRequiredParameter("Sections",      "SpecifiedSections",      False, True, DataParameters);
	SetRequiredParameter("Objects",      "SpecifiedObjects",      False, True, DataParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure SetRequiredParameter(ParameterName, RequiredParameterName, ValueWhenNotUsed, ValueWhenUndefined, DataParameters)
	
	Parameter = DataParameters.custom.FindParameterValue(New DataCompositionParameter(ParameterName));
	
	If Parameter.Use Then
		SpecifiedValue = Parameter.Value;
	Else
		// Setting value when the user didn't use filter.
		SpecifiedValue = ValueWhenNotUsed;
	EndIf;
	
	If TypeOf(SpecifiedValue) = Type("ValueList") Then
		// Creating new list for value type content extension.
		NewList = New ValueList;
		NewList.LoadValues(SpecifiedValue.UnloadValues());
		SpecifiedValue = NewList;
		// Setting the value when user specified the Undefined.
		Item = SpecifiedValue.FindByValue(Undefined);
		If Item <> Undefined Then
			Item.Value = ValueWhenUndefined;
		EndIf;
		//
	ElsIf SpecifiedValue = Undefined Then
		// Setting the value when user specified the Undefined.
		SpecifiedValue = ValueWhenUndefined;
	EndIf;
	
	DataParameters.Current.SetParameterValue(RequiredParameterName, SpecifiedValue);
	
EndProcedure

#EndRegion

#EndIf