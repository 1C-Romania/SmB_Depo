
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("OpeningMode") Then
		WindowOpeningMode = Parameters.OpeningMode;
	EndIf;
	
EndProcedure
