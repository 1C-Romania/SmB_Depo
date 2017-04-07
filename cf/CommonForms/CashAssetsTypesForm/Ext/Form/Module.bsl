
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Selection = Enums.CashAssetTypes.Noncash;
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	Close(Selection);
	
EndProcedure
