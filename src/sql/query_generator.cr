module ActiveRecord
  module Sql
    struct Query
      EMPTY_PARAMS = {} of String => ::ActiveRecord::SupportedType

      getter query
      getter params

      def self.[](*args)
        new(*args)
      end

      def initialize(@query, @params = EMPTY_PARAMS)
      end

      def concat_with(separator, other, parenthesis)
        Query.new("#{self.query(parenthesis)}#{separator}#{other.query(parenthesis)}",
                  self.params.merge(other.params))
      end

      def wrap_with(prefix, suffix, parenthesis)
        Query.new("#{prefix}#{query(parenthesis)}#{suffix}", params)
      end

      protected def query(parenthesis)
        return query unless parenthesis
        "(#{query})"
      end
    end

    class QueryGenerator < ::ActiveRecord::QueryGenerator
      alias HandledTypes = ::ActiveRecord::SupportedType|::ActiveRecord::Query

      class Fail < ArgumentError
      end

      def generate(query : HandledTypes, param_count = 0)
        ::ActiveRecord::QueryGenerator::Response.lift(_generate(query, param_count))
      rescue Fail
        ::ActiveRecord::QueryGenerator::Next.new
      end

      def generate(query, param_count = 0)
        ::ActiveRecord::QueryGenerator::Next.new
      end

      def _generate(query : ::ActiveRecord::Query, param_count = 0)
        _generate(query.expression.not_nil!, param_count)
      end

      def _generate(query : ::ActiveRecord::Criteria, param_count = 0)
        Query.new(query.to_s)
      end

      def _generate(query : ::ActiveRecord::Query::Equal, param_count = 0)
        generate_binary_op(query, " = ", param_count)
      end

      def _generate(query : ::ActiveRecord::Query::NotEqual, param_count = 0)
        generate_binary_op(query, " <> ", param_count)
      end

      def _generate(query : ::ActiveRecord::Query::Greater, param_count = 0)
        generate_binary_op(query, " > ", param_count)
      end

      def _generate(query : ::ActiveRecord::Query::GreaterEqual, param_count = 0)
        generate_binary_op(query, " >= ", param_count)
      end

      def _generate(query : ::ActiveRecord::Query::Less, param_count = 0)
        generate_binary_op(query, " < ", param_count)
      end

      def _generate(query : ::ActiveRecord::Query::LessEqual, param_count = 0)
        generate_binary_op(query, " <= ", param_count)
      end

      def _generate(query : ::ActiveRecord::Query::Or, param_count = 0)
        generate_binary_op(query, " OR ", param_count, parenthesis: true)
      end

      def _generate(query : ::ActiveRecord::Query::Xor, param_count = 0)
        generate_binary_op(query, " XOR ", param_count, parenthesis: true)
      end

      def _generate(query : ::ActiveRecord::Query::And, param_count = 0)
        generate_binary_op(query, " AND ", param_count, parenthesis: true)
      end

      def _generate(query : ::ActiveRecord::Query::Not, param_count = 0)
        generate_unary_op(query, param_count, parenthesis: true, prefix: "NOT ")
      end

      def _generate(query : ::ActiveRecord::Query::IsTrue, param_count = 0)
        generate_unary_op(query, param_count, parenthesis: true, suffix: " IS TRUE")
      end

      def _generate(query : ::ActiveRecord::Query::IsNotTrue, param_count = 0)
        generate_unary_op(query, param_count, parenthesis: true, suffix: " IS NOT TRUE")
      end

      def _generate(query : ::ActiveRecord::Query::IsFalse, param_count = 0)
        generate_unary_op(query, param_count, parenthesis: true, suffix: " IS FALSE")
      end

      def _generate(query : ::ActiveRecord::Query::IsNotFalse, param_count = 0)
        generate_unary_op(query, param_count, parenthesis: true, suffix: " IS NOT FALSE")
      end

      def _generate(query : ::ActiveRecord::Query::IsUnknown, param_count = 0)
        generate_unary_op(query, param_count, parenthesis: true, suffix: " IS UNKNOWN")
      end

      def _generate(query : ::ActiveRecord::Query::IsNotUnknown, param_count = 0)
        generate_unary_op(query, param_count, parenthesis: true, suffix: " IS NOT UNKNOWN")
      end

      def _generate(query : ::ActiveRecord::Query::IsNull, param_count = 0)
        generate_unary_op(query, param_count, parenthesis: true, suffix: " IS NULL")
      end

      def _generate(query : ::ActiveRecord::Query::IsNotNull, param_count = 0)
        generate_unary_op(query, param_count, parenthesis: true, suffix: " IS NOT NULL")
      end

      def _generate(query : ::ActiveRecord::SupportedType, param_count = 0)
        param_count += 1
        Query.new(":#{param_count}", { "#{param_count}" => query })
      end

      def _generate(query, params_count)
        raise Fail.new
      end

      private def generate_binary_op(query, separator, param_count, parenthesis = false)
        query_a = _generate(query.receiver, param_count)
        param_count += query_a.params.keys.count

        query_b = _generate(query.argument, param_count)

        query_a.concat_with(separator, query_b, parenthesis)
      end

      private def generate_unary_op(query, param_count, parenthesis = false, prefix = "", suffix = "")
        query_a = _generate(query.receiver, param_count)

        query_a.wrap_with(prefix, suffix, parenthesis)
      end
    end
  end
end
