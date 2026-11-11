# Extra make targets used by mayhem/build.sh (included via `make -f Makefile -f mayhem/mayhem.mk`).
# Upstream's Makefile supplies SRCS/OBJS/CFLAGS/LIBS; these only expose the object lists and a
# unit-test runner link that the Makefile builds inline inside `test-unit`.

mayhem-objs: $(filter-out $(OBJ_DIR)/src/main.o,$(OBJS)) $(OBJ_DIR)/fuzz/harness.o

$(OBJ_DIR)/fuzz/harness.o: fuzz/harness.c
	@$(MKDIR) $(@D)
	$(CC) $(CFLAGS) -Wno-sign-conversion -Wno-switch-default -Wno-cast-align -Wno-implicit-fallthrough -Wno-redundant-decls -c $< -o $@

mayhem-print-objs:
	@echo $(filter-out $(OBJ_DIR)/src/main.o,$(OBJS))

mayhem-unit: $(TOOL_BASE_OBJS) $(DRIVER_OBJS) $(UNIT_TEST_LSP_OBJS)
	@$(MKDIR) $(OBJ_DIR)/tests/unit
	$(CC) $(CFLAGS) -isystem tests/vendor -I tests/unit $(UNIT_TEST_SRCS) $(TOOL_BASE_OBJS) $(DRIVER_OBJS) $(UNIT_TEST_LSP_OBJS) -o $(OBJ_DIR)/tests/unit/run_unit $(LIBS)
