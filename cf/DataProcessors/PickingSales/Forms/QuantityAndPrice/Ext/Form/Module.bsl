
// Service

&AtServer
Procedure SetEnabled(Parameters)
	
	CommonUseClientServer.SetFormItemProperty(Items, "Quantity",		"Enabled", Parameters.RequestQuantity);
	CommonUseClientServer.SetFormItemProperty(Items, "MeasurementUnit",	"Enabled", Parameters.RequestPrice);
	
	AllowedToChangeAmount = ?(Parameters.RequestPrice, Parameters.AllowedToChangeAmount, Parameters.RequestPrice);
	CommonUseClientServer.SetFormItemProperty(Items, "Price", 				"Enabled", AllowedToChangeAmount);
	
	// If you request only a price, position focus on the Price attribute at once
	If Not Parameters.RequestQuantity
		AND Parameters.RequestPrice Then
		
		ThisForm.CurrentItem = Items.Price;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateLabelTotalAmount()
	
	Items.DecorationAmount.Title = 
		PickProductsAndServicesInDocumentsClientServer.AmountFormattedString(Quantity * Price);
	
EndProcedure

// Form

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Quantity			= Parameters.Quantity;
	MeasurementUnit	= Parameters.MeasurementUnit;
	Price				= Parameters.Price;
	
	SetEnabled(Parameters.SelectionSettingsCache);
	
	Items.DecorationAmount.Title = 
		PickProductsAndServicesInDocumentsClientServer.AmountFormattedString(Quantity * Price);
	
EndProcedure

//Commands

&AtClient
Procedure OK(Command)
	
	Close(New Structure("Quantity, MeasurementUnit, Price", Quantity, MeasurementUnit, Price));
	
EndProcedure

// Form attributes

&AtClient
Procedure QuantityOnChange(Item)
	
	UpdateLabelTotalAmount();
	
EndProcedure

&AtClient
Procedure PriceOnChange(Item)
	
	UpdateLabelTotalAmount();
	
EndProcedure

















