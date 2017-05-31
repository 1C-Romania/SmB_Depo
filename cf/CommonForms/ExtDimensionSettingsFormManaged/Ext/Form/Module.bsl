
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	List.Load(Parameters.ListTable.Unload());
EndProcedure

&AtClient
Procedure Ok(Command)
	
	NotifyChoice(List); 	

EndProcedure

