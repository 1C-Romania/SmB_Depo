
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



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
