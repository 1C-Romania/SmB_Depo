
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FillStructure = New Structure();
	FillStructure.Insert("Company", CommandExecuteParameters.Source.Object.Company);
	FillStructure.Insert("PriceKind", CommandExecuteParameters.Source.Object.PriceKind);
	FillStructure.Insert("WorkKind", CommandExecuteParameters.Source.Object.WorkKind);
	FillStructure.Insert("StructuralUnit", CommandExecuteParameters.Source.Object.SalesStructuralUnit);
	
	WorkCurrentString = Undefined;
	InventoryCurrentRow = Undefined;
	If CommandExecuteParameters.Source.Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerOrder.JobOrder") Then
		WorkCurrentString = CommandExecuteParameters.Source.Items.Works.CurrentData;
		FillStructure.Insert("WorkKind", CommandExecuteParameters.Source.Object.WorkKind);
	Else
		InventoryCurrentRow = CommandExecuteParameters.Source.Items.Inventory.CurrentData;
	EndIf;
	
	If InventoryCurrentRow <> Undefined AND Not InventoryCurrentRow.ProductsAndServicesTypeInventory Then
		
		StructureRow = New Structure;
		StructureRow.Insert("ProductsAndServices", InventoryCurrentRow.ProductsAndServices);
		StructureRow.Insert("Characteristic", InventoryCurrentRow.Characteristic);
		StructureRow.Insert("Day", InventoryCurrentRow.ShipmentDate);
		StructureRow.Insert("Price", InventoryCurrentRow.Price);
		StructureRow.Insert("Amount", InventoryCurrentRow.Amount);
		StructureRow.Insert("Customer", CommandExecuteParameters.Source.Object.Ref);
		
		Array = New Array;
		Array.Add(StructureRow);
		
		FillStructure.Insert("Works", Array);
		
	ElsIf WorkCurrentString <> Undefined Then
		
		StructureRow = New Structure;
		StructureRow.Insert("WorkKind", WorkCurrentString.WorkKind);
		StructureRow.Insert("ProductsAndServices", WorkCurrentString.ProductsAndServices);
		StructureRow.Insert("Characteristic", WorkCurrentString.Characteristic);
		StructureRow.Insert("Day", CommandExecuteParameters.Source.Object.Start);
		
		DurationInHours = WorkCurrentString.Quantity * WorkCurrentString.Multiplicity * WorkCurrentString.Factor;
		If DurationInHours >= 24 Then
			DurationInHours = (EndOfDay(CommandExecuteParameters.Source.Object.Start) - CommandExecuteParameters.Source.Object.Start) / 3600;
		EndIf;  
		
		StructureRow.Insert("DurationInHours", DurationInHours);
		
		DurationInSeconds = DurationInHours * 3600;
		Hours = Int(DurationInSeconds / 3600);
		Minutes = (DurationInSeconds - Hours * 3600) / 60;
		Duration = Date(0001, 01, 01, Hours, Minutes, 0);
		StructureRow.Insert("Duration", Duration);
		
		Start = Date(0001, 01, 01, Hour(CommandExecuteParameters.Source.Object.Start), Minute(CommandExecuteParameters.Source.Object.Start), 0);
		StructureRow.Insert("BeginTime", Start);
		StructureRow.Insert("EndTime", Start + DurationInHours * 3600);
		
		StructureRow.Insert("Price", WorkCurrentString.Price);
		StructureRow.Insert("Amount", WorkCurrentString.Amount);
		StructureRow.Insert("Customer", CommandExecuteParameters.Source.Object.Ref);
		
		Array = New Array;
		Array.Add(StructureRow);
		
		FillStructure.Insert("Works", Array);
		
		RowsArrayExecutors = CommandExecuteParameters.Source.Object.Performers.FindRows(New Structure("ConnectionKey", WorkCurrentString.ConnectionKey));
		For Each StringPerformers IN RowsArrayExecutors Do
			FillStructure.Insert("Employee", StringPerformers.Employee);
			Break;
		EndDo;
		
	Else
		
		StructureRow = New Structure;
		StructureRow.Insert("Customer", CommandExecuteParameters.Source.Object.Ref);
		
		Array = New Array;
		Array.Add(StructureRow);
		
		FillStructure.Insert("Works", Array);
		
	EndIf;
	
	OpenForm("Document.WorkOrder.ObjectForm", New Structure("Basis", FillStructure));
	
EndProcedure
