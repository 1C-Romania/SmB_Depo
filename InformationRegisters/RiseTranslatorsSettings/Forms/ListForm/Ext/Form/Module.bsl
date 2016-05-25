
&AtServer
Procedure ResetSessionParametersAtServer()
	RiseTranslation.SessionParametersSetting();
EndProcedure

&AtClient
Procedure ResetSessionParameters(Command)
	ResetSessionParametersAtServer();
EndProcedure
