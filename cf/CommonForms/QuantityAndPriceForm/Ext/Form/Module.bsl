
&AtClient
Procedure OK(Command)
	
	Close(New Structure("MeasurementUnit, Quantity, Price", MeasurementUnit, Quantity, Price));
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(ThisForm, Parameters.FillValue);
	
	If Parameters.FillValue.Property("UOMOwner") Then
		
		ProductsAndServices 		= Parameters.FillValue.UOMOwner;
		MeasurementUnit	= ?(ValueIsFilled(ProductsAndServices), ProductsAndServices.MeasurementUnit, Catalogs.UOM.EmptyRef());
		
	EndIf;
	
	Items.Price.Enabled = PriceAvailable;
	
EndProcedure














