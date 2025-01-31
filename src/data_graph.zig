const graph = @import("graph.zig").Graph;
const std = @import("std");
const ArrayList = std.ArrayList;
const graph_err = @import("graph.zig").GraphError;
const testing = std.testing;
const AutoArrayHashMap = std.AutoArrayHashMap;
const mem = std.mem;
const testing_alloc = std.testing.allocator;

pub fn DataGraph(comptime index_type: type, comptime node_type: type, comptime edge_type: type, comptime directed: bool) type {
    return struct {
        const Self = @This();
        graph: graph(index_type, directed),
        node_data: AutoArrayHashMap(index_type, node_type),
        edge_data: AutoArrayHashMap(index_type, edge_type),
        allocator: mem.Allocator,
        pub fn init(alloc: mem.Allocator) Self {
            return Self{ .graph = graph(index_type, directed).init(alloc), .node_data = AutoArrayHashMap(index_type, node_type).init(alloc), .edge_data = AutoArrayHashMap(index_type, edge_type).init(alloc), .allocator = alloc };
        }
        pub fn deinit(self: *Self) !void {
            try self.graph.deinit();
            self.node_data.deinit();
            self.edge_data.deinit();
        }

        //Adds a node given an index, and node data
        pub fn addNode(self: *Self, node_index: index_type, node_data: node_type) !void {
            try self.graph.addNode(node_index);
            try self.node_data.put(node_index, node_data);
        }

        //Adds an edge given an index, the indices of the nodes being connected (order matters for directed), and an edge type
        pub fn addEdge(self: *Self, id: index_type, n1: index_type, n2: index_type, edge_data: edge_type) !void {
            try self.graph.addEdge(id, n1, n2);
            try self.edge_data.put(id, edge_data);
        }

        //Removes an edge by its ID
        pub fn removeEdgeByID(self: *Self, id: index_type) !void {
            try self.graph.removeEdgeByID(id);
            _ = self.edge_data.orderedRemove(id);
        }

        //Removes the edges between two nodes, note that for directed graphs order matters (only edges from n1 to n2 will be removed for directed)
        pub fn removeEdgesBetween(self: *Self, n1: index_type, n2: index_type) !ArrayList(index_type) {
            var removed_edges = try self.graph.removeEdgesBetween(n1, n2);
            for (removed_edges.items) |edge| {
                _ = self.edge_data.orderedRemove(edge);
            }
            return removed_edges;
        }

        //Removes a node with all of its edges
        pub fn removeNodeWithEdges(self: *Self, id: index_type) !ArrayList(index_type) {
            var removed_edges = try self.graph.removeNodeWithEdges(id);
            for (removed_edges.items) |edge| {
                _ = self.edge_data.orderedRemove(edge);
            }
            _ = self.node_data.orderedRemove(id);
            return removed_edges;
        }

        //Gets the data of all nodes with indices given by an array list
        pub fn getNodesData(self: *Self, ids: ArrayList(index_type)) !ArrayList(node_type) {
            var data = ArrayList(node_type).init(self.allocator);
            data.deinit();
            for (ids.items) |id| {
                if (!self.node_data.contains(id)) {
                    data.deinit();
                    return graph_err.NodesDoNotExist;
                }
                try data.append(self.node_data.get(id).?);
            }
            return data;
        }

        //Gets the data of all edges with indices given by an array list
        pub fn getEdgesData(self: *Self, ids: ArrayList(index_type)) !ArrayList(edge_type) {
            var data = ArrayList(edge_type).init(self.allocator);
            data.deinit();
            for (ids.items) |id| {
                if (!self.edge_data.contains(id)) {
                    data.deinit();
                    return graph_err.EdgesDoNotExist;
                }
                try data.append(self.edge_data.get(id).?);
            }
            return data;
        }
    };
}

test "nominal-addNode" {
    var data_graph = DataGraph(u32, u64, u64, true).init(testing_alloc);
    try data_graph.addNode(3, 4);
    try testing.expect(data_graph.graph.graph.count() == 1);
    try testing.expect(data_graph.node_data.count() == 1);
    try testing.expect(data_graph.node_data.get(3).? == 4);
    try data_graph.deinit();
}
test "nominal-addEdge" {
    var data_graph = DataGraph(u32, u64, u64, true).init(testing_alloc);
    try data_graph.addNode(3, 4);
    try data_graph.addNode(4, 5);
    try data_graph.addEdge(1, 3, 4, 6);
    try testing.expect(data_graph.edge_data.get(1).? == 6);
    try data_graph.deinit();
}
test "offnominal-addNode" {
    var data_graph = DataGraph(u32, u64, u64, true).init(testing_alloc);
    try data_graph.addNode(3, 4);
    try testing.expect(if (data_graph.addNode(3, 4)) |_| unreachable else |err| err == graph_err.NodeAlreadyExists);
    try data_graph.deinit();
}
test "nominal-removeNodeWithEdges" {
    var data_graph = DataGraph(u32, u64, u64, true).init(testing_alloc);
    try data_graph.addNode(3, 4);
    try data_graph.addNode(4, 4);
    try data_graph.addEdge(1, 3, 4, 6);
    var edges = try data_graph.removeNodeWithEdges(3);
    try testing.expect(data_graph.graph.graph.count() == 1);
    try testing.expect(data_graph.node_data.count() == 1);
    try testing.expect(data_graph.edge_data.count() == 0);
    try testing.expect(edges.items.len == 1);
    edges.deinit();
    try data_graph.deinit();
}
test "offnominal-removeNodeWithEdges" {
    var data_graph = DataGraph(u32, u64, u64, true).init(testing_alloc);
    try data_graph.addNode(3, 4);
    try testing.expect(if (data_graph.removeNodeWithEdges(2)) |_| unreachable else |err| err == graph_err.NodesDoNotExist);
    try data_graph.deinit();
}
test "nominal-removeEdgeByID" {
    var data_graph = DataGraph(u32, u64, u64, true).init(testing_alloc);
    try data_graph.addNode(3, 4);
    try data_graph.addNode(4, 4);
    try data_graph.addEdge(1, 3, 4, 6);
    try data_graph.removeEdgeByID(1);
    try testing.expect(data_graph.edge_data.count() == 0);
    try data_graph.deinit();
}
test "offnominal-removeEdgeByID" {
    var data_graph = DataGraph(u32, u64, u64, true).init(testing_alloc);
    try data_graph.addNode(3, 4);
    try data_graph.addNode(4, 4);
    try data_graph.addEdge(1, 3, 4, 6);
    try testing.expect(if (data_graph.removeEdgeByID(2)) |_| unreachable else |err| err == graph_err.EdgesDoNotExist);
    try data_graph.deinit();
}
test "nominal-removeEdgesBetween" {
    var data_graph = DataGraph(u32, u64, u64, true).init(testing_alloc);
    try data_graph.addNode(3, 4);
    try data_graph.addNode(4, 4);
    try data_graph.addEdge(1, 3, 4, 6);
    try data_graph.addEdge(2, 3, 4, 6);
    var edges = try data_graph.removeEdgesBetween(3, 4);
    try testing.expect(data_graph.edge_data.count() == 0);
    try testing.expect(edges.items.len == 2);
    edges.deinit();
    try data_graph.deinit();
}
test "offnominal-removeEdgesBetween" {
    var data_graph = DataGraph(u32, u64, u64, true).init(testing_alloc);
    try data_graph.addNode(3, 4);
    try data_graph.addNode(4, 4);
    try data_graph.addEdge(1, 3, 4, 6);
    try data_graph.addEdge(2, 3, 4, 6);
    try testing.expect(if (data_graph.removeEdgesBetween(4, 5)) |_| unreachable else |err| err == graph_err.NodesDoNotExist);
    try data_graph.deinit();
}
test "nominal-getNodesData" {
    var data_graph = DataGraph(u32, u64, u64, true).init(testing_alloc);
    try data_graph.addNode(3, 4);
    try data_graph.addNode(4, 5);
    var arr = ArrayList(u32).init(testing_alloc);
    try arr.append(3);
    try arr.append(4);
    var node_data = try data_graph.getNodesData(arr);
    try testing.expect(node_data.items[0] == 4);
    try testing.expect(node_data.items[1] == 5);
    node_data.deinit();
    arr.deinit();
    try data_graph.deinit();
}
test "offnominal-getNodesData" {
    var data_graph = DataGraph(u32, u64, u64, true).init(testing_alloc);
    try data_graph.addNode(3, 4);
    try data_graph.addNode(4, 5);
    var arr = ArrayList(u32).init(testing_alloc);
    try arr.append(1);
    try arr.append(7);
    try testing.expect(if (data_graph.getNodesData(arr)) |_| unreachable else |err| err == graph_err.NodesDoNotExist);
    arr.deinit();
    try data_graph.deinit();
}
test "nominal-getEdgesData" {
    var data_graph = DataGraph(u32, u64, u64, true).init(testing_alloc);
    try data_graph.addNode(3, 4);
    try data_graph.addNode(4, 5);
    try data_graph.addEdge(1, 3, 4, 6);
    try data_graph.addEdge(2, 3, 4, 7);
    var arr = ArrayList(u32).init(testing_alloc);
    try arr.append(1);
    try arr.append(2);
    var node_data = try data_graph.getEdgesData(arr);
    try testing.expect(node_data.items[0] == 6);
    try testing.expect(node_data.items[1] == 7);
    node_data.deinit();
    arr.deinit();
    try data_graph.deinit();
}
test "offnominal-getEdgesData" {
    var data_graph = DataGraph(u32, u64, u64, true).init(testing_alloc);
    try data_graph.addNode(3, 4);
    try data_graph.addNode(4, 5);
    try data_graph.addEdge(1, 3, 4, 6);
    try data_graph.addEdge(2, 3, 4, 7);
    var arr = ArrayList(u32).init(testing_alloc);
    try arr.append(1);
    try arr.append(7);
    try testing.expect(if (data_graph.getEdgesData(arr)) |_| unreachable else |err| err == graph_err.EdgesDoNotExist);
    arr.deinit();
    try data_graph.deinit();
}
