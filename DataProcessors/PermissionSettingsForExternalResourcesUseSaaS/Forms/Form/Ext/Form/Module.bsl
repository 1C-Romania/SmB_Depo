
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Raise NStr("en = 'DataProcessor is not intended for interactive use!'");
	
EndProcedure
