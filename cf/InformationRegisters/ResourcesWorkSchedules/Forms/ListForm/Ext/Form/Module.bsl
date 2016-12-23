
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("EnterpriseResource") Then
		SmallBusinessClientServer.SetListFilterItem(List, "EnterpriseResource", Parameters.EnterpriseResource);
	EndIf;
	
EndProcedure














