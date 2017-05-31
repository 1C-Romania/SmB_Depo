// StringToParametrize - String with parameters names. Recommended to name parameters %P1,%P2- and so one 
// ParametersStructure - Structure which contains parameter name (without %-symbol) as key and parameters value as value 
Function ParametrizeString(StringToParametrize,ParametersStructure) Export

	If ParametersStructure = Undefined Then
		Return StringToParametrize;
	EndIf;
	
	LocalStringToParametrize = StringToParametrize;
	
	Array = New Array();
	
	For Each KeyAndValue In ParametersStructure Do
		Array.Insert(0,KeyAndValue.Key);	
	EndDo;
	
	For Each ValueInArray In Array Do
		LocalStringToParametrize = StrReplace(LocalStringToParametrize,String("%"+ValueInArray),String(ParametersStructure[ValueInArray]));
	EndDo;	
	
	Return LocalStringToParametrize;
	
EndFunction
