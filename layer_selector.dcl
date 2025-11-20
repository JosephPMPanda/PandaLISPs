layer_selector : dialog {
    label = "Copy/Move Objects to Layers";
    width = 50;
    
    : boxed_column {
        label = "Layer Selection";
        
        : edit_box {
            key = "search_box";
            label = "Search layers:";
            edit_width = 30;
        }
        
        : text {
            key = "search_status";
            label = "";
        }
        
        : row {
            : button {
                key = "create_layer_btn";
                label = "Create Layer from Search";
                width = 25;
            }
        }
        
        : list_box {
            key = "layer_list";
            label = "Available Layers (Click to select multiple):";
            height = 15;
            width = 40;
            fixed_width = true;
            allow_accept = true;
        }
        
        : text {
            key = "selection_info";
            label = "No layers selected";
        }
    }
    
    : row {
        : button {
            key = "copy_btn";
            label = "Copy";
            width = 12;
        }
        : button {
            key = "move_btn";
            label = "Move";
            width = 12;
        }
        : button {
            key = "cancel";
            label = "Cancel";
            width = 12;
            is_cancel = true;
        }
    }
}