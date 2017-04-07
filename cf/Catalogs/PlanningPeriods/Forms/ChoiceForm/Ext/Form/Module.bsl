
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ExcludeActualPeriod") AND Parameters.ExcludeActualPeriod Then
		List.Parameters.SetParameterValue("ExcludeActualPeriod", True);
	Else
		List.Parameters.SetParameterValue("ExcludeActualPeriod", False);
	EndIf;
		
EndProcedure
