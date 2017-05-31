#Region Getters

Function GetSettingsParameter(Settings,Val ParameterName) Export
	Return Settings.DataParameters.FindParameterValue(New DataCompositionParameter(ParameterName));
EndFunction	

Function GetOutputParameter(Settings,Val ParameterName) Export
	Return Settings.OutputParameters.FindParameterValue(New DataCompositionParameter(ParameterName));
EndFunction	

Function GetTitleOutputParameter(Settings) Export
	Return GetOutputParameter(Settings,"TitleOutput");	
EndFunction	

#EndRegion


#Region Setters
// returns True in case parameter was set, False when parameter wasn't found
Function SetSettingsParameter(Settings, Val ParameterName, Val Value) Export
	If GetSettingsParameter(Settings, ParameterName) = Undefined Then
		Return False;
	Else
		Settings.DataParameters.SetParameterValue(ParameterName,Value);
		Return True;
	EndIf	
EndFunction	

Function SetOutputParameter(Settings,Val ParameterName, Val Value) Export
	If GetOutputParameter(Settings, ParameterName) = Undefined Then
		Return False;
	Else
		Settings.OutputParameters.SetParameterValue(ParameterName,Value);
		Return True;
	EndIf;	
EndFunction	


Function SetTitleOutputParameter(Settings,Val Value) Export
	Return SetOutputParameter(Settings, "TitleOutput", Value);	
EndFunction	
	
#EndRegion