
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Record.Attribute<>Undefined then
		
		ArrayTypes = New Array;
		ArrayTypes.Add(TypeOf(Record.DataType));
		
		DataTypeDescription = New TypeDescription(ArrayTypes);
	EndIf;
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	SelectTypeValue = DataTypeDescription.AdjustValue();
	
	If SelectTypeValue<>Undefined then
		Record.DataType = SelectTypeValue;
	Else
		Cancel = True;
		Message = New UserMessage;
		Message.Text = NStr("en='Please choose data value type';pl='Wybrierz typ wartości danych';ru='Выберите тип значения данных'");
		Message.Field = "Items.AttributeTypeDescription";
		Message.Message();
	Endif;	
EndProcedure

