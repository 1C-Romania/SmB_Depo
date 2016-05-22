
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	WorkCurrentString = CommandExecuteParameters.Source.Items.Works.CurrentData;
	
	FillStructure = New Structure();
	FillStructure.Insert("Basis", CommandExecuteParameters.Source.Object.Ref);
	
	If WorkCurrentString <> Undefined Then
		
		FillStructure.Insert("Customer", WorkCurrentString.Customer);
		FillStructure.Insert("BeginTime", WorkCurrentString.BeginTime);
		FillStructure.Insert("EndTime", WorkCurrentString.EndTime);
		FillStructure.Insert("Day", WorkCurrentString.Day);
		
	EndIf;
	
	OpenForm("Document.Event.ObjectForm", New Structure("Basis", FillStructure));
	
EndProcedure
