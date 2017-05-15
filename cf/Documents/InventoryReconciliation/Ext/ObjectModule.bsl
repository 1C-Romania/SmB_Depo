

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	// Serial numbers
	If WorkWithSerialNumbers.UseSerialNumbersBalance() = True Then
	
		For Each StringInventory In Inventory Do
			If StringInventory.ProductsAndServices.UseSerialNumbers Then
				FilterSerialNumbers = New Structure("ConnectionKey", StringInventory.ConnectionKey);
				FilterSerialNumbers = SerialNumbers.FindRows(FilterSerialNumbers);
				
				If TypeOf(StringInventory.MeasurementUnit)=Type("CatalogRef.UOM") Then
				    Ratio = StringInventory.MeasurementUnit.Ratio;
				Else
					Ratio = 1;
				EndIf;
				
				RowInventoryQuantity = StringInventory.Quantity * Ratio;
				
				If FilterSerialNumbers.Count() <> RowInventoryQuantity Then
					MessageText = NStr("ru = 'Число серийных номеров отличается от количества единиц в строке %Number%.'; en = 'The quantity of serial numbers differs from the quantity of units in line %Number%.'");
					MessageText = MessageText + NStr("ru = ' Серийных номеров - %QuantityOfNumbers%, нужно %QuantityInRow%'; en = 'Serial numbers - %QuantityOfNumbers%, need %QuantityInRow%'");
					MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
					MessageText = StrReplace(MessageText, "%QuantityOfNumbers%", FilterSerialNumbers.Count());
					MessageText = StrReplace(MessageText, "%QuantityInRow%", RowInventoryQuantity);
					
					Message = New UserMessage();
					Message.Text = MessageText;
					Message.Message();
					
				EndIf;
			EndIf; 
		EndDo;
	
	EndIf;
EndProcedure